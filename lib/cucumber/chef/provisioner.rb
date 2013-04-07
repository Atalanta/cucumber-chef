################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
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

    class ProvisionerError < Error; end

    class Provisioner
      attr_accessor :test_lab

################################################################################

      def initialize(test_lab, ui=ZTK::UI.new)
        test_lab.nil? and raise ProvisionerError, "You must supply a test lab!"

        @test_lab = test_lab
        @ui       = ui

        @cookbooks_path = File.join(Cucumber::Chef.root_dir, "chef_repo", "cookbooks")
        @roles_path = File.join(Cucumber::Chef.root_dir, "chef_repo", "roles")
      end

################################################################################

      def build
        upload_chef_repo
        bootstrap
        wait_for_chef_server

        download_chef_credentials
        download_proxy_ssh_credentials

        reboot_test_lab
      end


################################################################################
    private
################################################################################

      def upload_chef_repo
        ZTK::Benchmark.bench(:message => "Uploading embedded chef-repo", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          local_path = File.join(Cucumber::Chef.root_dir, "chef_repo")
          @ui.logger.debug { "local_path == #{local_path.inspect}" }

          remote_path = File.join("/tmp", "chef-solo")
          @ui.logger.debug { "remote_path == #{remote_path.inspect}" }

          # FIXME!
          # there seems to be a major difference between net-sftp v2.0.5 and
          # v2.1.1; under v2.0.5 the remote_path is expected to exist already so
          # if it is not in place mkdir fails with Net::SFTP::StatusException on
          # the Net::SFTP mkdir internal call triggered by a Net::SFTP upload
          # call
          @test_lab.bootstrap_ssh.exec(%(sudo rm -rf #{remote_path}), :silence => true)
          begin
            @test_lab.bootstrap_ssh.upload(local_path, remote_path)
          rescue Net::SFTP::StatusException => e
            @test_lab.bootstrap_ssh.exec(%(mkdir -p #{remote_path}), :silence => true)
            retry
          end
        end
      end

################################################################################

      def bootstrap
        raise ProvisionerError, "You must have the environment variable 'USER' set." if !Cucumber::Chef::Config.user

        ZTK::Benchmark.bench(:message => "Bootstrapping #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :ui => @ui) do

          chef_solo_attributes = case Cucumber::Chef.chef_pre_11
          when true then
            {
              "chef-server" => {
                "webui_enabled" => true
              },
              "run_list" => %w(recipe[chef-server::rubygems-install] recipe[chef-server::apache-proxy] role[test_lab])
            }
          when false then
            {
              "chef-server" => {
                "nginx" => {
                  "enable_non_ssl" => true,
                  "server_name" => "localhost",
                  "url" => "http://localhost"
                },
                "chef_server_webui" => {
                  "enable" => true
                }
              },
              "run_list" => %w(recipe[chef-server::default] role[test_lab])
            }
          end

          chef_solo_attributes.merge!(
            "cucumber_chef" => {
              "version" => Cucumber::Chef::VERSION,
              "prerelease" => Cucumber::Chef::Config.prerelease,
              "lab_user" => Cucumber::Chef.lab_user,
              "lxc_user" => Cucumber::Chef.lxc_user
            }
          )

          context = {
            :chef_pre_11 => Cucumber::Chef.chef_pre_11,
            :chef_solo_attributes => chef_solo_attributes,
            :chef_version => Cucumber::Chef::Config.chef[:version],
            :chef_validator => (Cucumber::Chef.chef_pre_11 ? '/etc/chef/validation.pem' : '/etc/chef-server/chef-validator.pem'),
            :chef_webui => (Cucumber::Chef.chef_pre_11 ? '/etc/chef/webui.pem' : '/etc/chef-server/chef-webui.pem'),
            :chef_admin => (Cucumber::Chef.chef_pre_11 ? '/etc/chef/admin.pem' : '/etc/chef-server/admin.pem'),
            :default_password => Cucumber::Chef::Config.chef[:default_password],
            :user => Cucumber::Chef::Config.user,
            :hostname_short => Cucumber::Chef.lab_hostname_short,
            :hostname_full => Cucumber::Chef.lab_hostname_full
          }

          bootstrap_template = File.join(Cucumber::Chef.root_dir, "lib", "cucumber", "chef", "templates", "bootstrap", "ubuntu-precise-omnibus.erb")

          local_bootstrap_file = Tempfile.new("bootstrap")
          local_bootstrap_filename = local_bootstrap_file.path
          local_bootstrap_file.write(::ZTK::Template.render(bootstrap_template, context))
          local_bootstrap_file.close

          remote_bootstrap_filename = File.join('/tmp', 'cucumber-chef-bootstrap.sh')

          @test_lab.bootstrap_ssh.upload(local_bootstrap_filename, remote_bootstrap_filename)

          local_bootstrap_file.unlink

          command = "sudo /bin/bash #{remote_bootstrap_filename}"
          @test_lab.bootstrap_ssh.exec(command, :silence => true)
        end
      end

################################################################################

      def download_chef_credentials
        ZTK::Benchmark.bench(:message => "Downloading chef-server credentials", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          local_path = File.dirname(Cucumber::Chef.chef_identity)
          @ui.logger.debug { "local_path == #{local_path.inspect}" }

          remote_path = File.join(Cucumber::Chef.bootstrap_user_home_dir, ".chef")
          @ui.logger.debug { "remote_path == #{remote_path.inspect}" }

          files = [ File.basename(Cucumber::Chef.chef_identity) ]
          if (Cucumber::Chef.chef_pre_11 == true)
            files << "validation.pem"
          else
            files << "chef-validator.pem"
          end
          files.each do |file|
            @ui.logger.debug { "file == #{file.inspect}" }

            @test_lab.bootstrap_ssh.download(File.join(remote_path, file), File.join(local_path, file))
          end
        end
      end

################################################################################

      def download_proxy_ssh_credentials
        ZTK::Benchmark.bench(:message => "Downloading proxy SSH credentials", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          local_path = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s)
          remote_path = File.join(Cucumber::Chef.lab_user_home_dir, ".ssh")

          files = { "id_rsa" => "id_rsa-#{Cucumber::Chef.lab_user}" }
          files.each do |remote_file, local_file|
            tmp = File.join("/tmp", local_file)
            remote = File.join(remote_path, remote_file)
            local = File.join(local_path, local_file)
            File.exists?(local) and File.delete(local)
            @test_lab.bootstrap_ssh.exec(%(sudo cp -v #{remote} #{tmp} && sudo chown -v #{Cucumber::Chef.bootstrap_user}:#{Cucumber::Chef.bootstrap_user} #{tmp}), :silence => true)
            @test_lab.bootstrap_ssh.download(tmp, local)
            File.chmod(0600, local)
          end
        end
      end

################################################################################

      def chef_first_run
        ZTK::Benchmark.bench(:message => "Performing chef-client run", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          log_level = (ENV['LOG_LEVEL'].downcase rescue (Cucumber::Chef.is_rc? ? "debug" : "info"))

          command = "/usr/bin/chef-client -j /etc/chef/first-boot.json --log_level #{log_level} --once"
          command = "sudo #{command}"
          @test_lab.bootstrap_ssh.exec(command, :silence => true)
        end
      end

################################################################################

      def wait_for_chef_server
        ZTK::Benchmark.bench(:message => "Waiting for the chef-server-api HTTPS", :mark => "responded after %0.4f seconds.", :ui => @ui) do
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 443, :data => "GET", :wait => 120).wait
        end
      end

################################################################################

      def reboot_test_lab
        ZTK::Benchmark.bench(:message => "Rebooting the test lab", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          command = "sudo reboot"
          @test_lab.bootstrap_ssh.exec(command, :silence => true)
          sleep(10)
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => @test_lab.port, :wait => 120).wait
        end

        wait_for_chef_server
      end

    end

  end
end

################################################################################
