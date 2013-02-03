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

    class ClientError < Error; end

    class Client
      attr_accessor :test_lab

################################################################################

      def initialize(test_lab, ui=ZTK::UI.new)
        @test_lab = test_lab
        @ui = ui
      end

################################################################################

      def up(options={})
        user = Cucumber::Chef.lab_user
        home_dir = Cucumber::Chef.lab_user_home_dir
        provider = Cucumber::Chef::Config.provider.to_s
        @test_lab.ssh.exec("sudo mkdir -p #{File.join(home_dir, ".cucumber-chef", provider)}")
        @test_lab.ssh.exec("sudo cp -f #{File.join(home_dir, ".chef", "knife.rb")} #{File.join(home_dir, ".cucumber-chef", provider, "knife.rb")}")
        @test_lab.ssh.exec("sudo chown -R #{user}:#{user} #{File.join(home_dir, ".cucumber-chef")}")

        local_file = Cucumber::Chef.config_rb
        remote_file = File.join(home_dir, ".cucumber-chef", "config.rb")
        @test_lab.ssh.upload(local_file, remote_file)

        begin
          self.ping
        rescue
          @background = ZTK::Background.new
          @background.process do
            self.down

            environment = Array.new
            %w(PURGE VERBOSE LOG_LEVEL).each do |env_var|
              environment << "#{env_var}=#{ENV[env_var].inspect}" if (!ENV[env_var].nil? && !ENV[env_var].empty?)
            end
            environment = environment.join(" ")
            external_ip = Cucumber::Chef.external_ip

            command = %Q{nohup sudo #{environment} /usr/bin/env cc-server #{external_ip} &}

            @test_lab.ssh.exec(command, options)
          end

          Kernel.at_exit do
            self.at_exit
          end
        end

        ZTK::RescueRetry.try(:tries => 30) do
          self.drb.ping
        end

        File.exists?(Cucumber::Chef.artifacts_dir) && FileUtils.rm_rf(Cucumber::Chef.artifacts_dir)

        true
      end

################################################################################

      def down
        (@test_lab.drb.shutdown rescue nil)
      end

################################################################################

      def drb
        @drb and DRb.stop_service
        @drb = DRbObject.new_with_uri("druby://#{@test_lab.ip}:8787")
        @drb and DRb.start_service
        @drb
      end

################################################################################

      def before(scenario)
        # store the current scenario here; espcially since I don't know a better way to get at this information
        # we use various aspects of the scenario to name our artifacts
        $scenario = scenario

        @test_lab.drb.load_containers

        @test_lab.drb.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                             :validation_client_name => "chef-validator")
      end

################################################################################

      def after(scenario)
        @test_lab.drb.save_containers

        # cleanup non-persistent lxc containers after tests
        @test_lab.drb.containers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
          @test_lab.drb.server_destroy(name)
        end
      end

################################################################################

      def at_exit
        @ui.logger.fatal { "Waiting for cc-server to shutdown." }
        self.down
        @background.wait
      end

################################################################################

    end

  end
end

################################################################################
