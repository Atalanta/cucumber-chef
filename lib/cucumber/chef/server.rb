################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber
  module Chef

    class ServerError < Error; end

    class Server
      attr_accessor :test_lab, :stdout, :stderr, :stdin, :logger

################################################################################

      def initialize(test_lab, stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
        @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @test_lab = test_lab
      end

################################################################################

      def up
        user = Cucumber::Chef.lab_user
        home_dir = Cucumber::Chef.lab_user_home_dir
        provider = Cucumber::Chef::Config.provider.to_s
        @test_lab.ssh.exec("sudo mkdir -p #{File.join(home_dir, ".cucumber-chef", provider)}")
        @test_lab.ssh.exec("sudo cp -f #{File.join(home_dir, ".chef", "knife.rb")} #{File.join(home_dir, ".cucumber-chef", provider, "knife.rb")}")
        @test_lab.ssh.exec("sudo chown -R #{user}:#{user} #{File.join(home_dir, ".cucumber-chef")}")

        local_file = Cucumber::Chef.config_rb
        remote_file = File.join(home_dir, ".cucumber-chef", "config.rb")
        @test_lab.ssh.upload(local_file, remote_file)

        @server_thread = Thread.new do
          @test_lab.ssh.exec("sudo pkill -9 -f cc-server")

          destroy = (ENV['DESTROY'] == '1' ? "DESTROY='1'" : nil)
          verbose = (ENV['VERBOSE'] == '1' ? "VERBOSE='1'" : nil)
          log_level = ((!ENV['LOG_LEVEL'].nil? && !ENV['LOG_LEVEL'].empty?) ? "LOG_LEVEL=#{ENV['LOG_LEVEL'].inspect}" : nil)
          command = ["sudo", destroy, verbose, log_level, "cc-server", Cucumber::Chef.external_ip].compact.join(" ")
          @test_lab.ssh.exec(command, :silence => false)

          Kernel.at_exit do
            @test_lab.ssh.close
          end
        end

        sleep(3)
        ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 8787, :data => "\n\n").wait

        artifacts = File.join(Cucumber::Chef.home_dir, "artifacts")
        File.exists?(artifacts) && FileUtils.rm_rf(artifacts)

        @server_thread
      end

################################################################################

      def down
      end

################################################################################

      def before(scenario)
        # store the current scenario here; espcially since I don't know a better way to get at this information
        # we use various aspects of the scenario to name our artifacts
        $scenario = scenario

        # cleanup previous lxc containers if asked
        if ENV['DESTROY']
          Cucumber::Chef.logger.info("'containers' are being destroyed")
          @test_lab.drb.servers.each do |name, value|
            @test_lab.drb.server_destroy(name)
          end
          File.exists?(Cucumber::Chef.servers_bin) && File.delete(Cucumber::Chef.servers_bin)
        else
          Cucumber::Chef.logger.info("'containers' are being persisted")
        end

        if File.exists?(Cucumber::Chef.servers_bin)
          @test_lab.drb.servers = (Marshal.load(IO.read(Cucumber::Chef.servers_bin)) rescue Hash.new(nil))
        end

        @test_lab.drb.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                             :validation_client_name => "chef-validator")
      end

################################################################################

      def after(scenario)
        File.open(Cucumber::Chef.servers_bin, 'w') do |f|
          f.puts(Marshal.dump(@test_lab.drb.servers))
        end

        # cleanup non-persistent lxc containers between tests
        @test_lab.drb.servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
          @test_lab.drb.server_destroy(name)
        end
      end

################################################################################

      def at_exit
        @test_lab.drb.shutdown
        @server_thread.kill
      end

################################################################################

    end

  end
end

################################################################################
