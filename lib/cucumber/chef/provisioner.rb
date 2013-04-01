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
        @bootstrap_template = File.join(Cucumber::Chef.root_dir, "lib", "cucumber", "chef", "templates", "bootstrap", "ubuntu-precise-test-lab.erb")
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

          glob_dir = File.join(local_path, "**")
          @ui.logger.debug { "glob_dir == #{glob_dir.inspect}" }

          @test_lab.bootstrap_ssh.exec(%(mkdir -p #{remote_path}))

          Dir.glob(glob_dir).each do |file|
            file = File.basename(file)
            @ui.logger.debug { "file == #{file.inspect}" }

            local_file = File.join(local_path, file)
            remote_file = File.join(remote_path, file)

            File.directory?(local_file) and @test_lab.bootstrap_ssh.exec(%(mkdir -p #{remote_file}))

            @test_lab.bootstrap_ssh.upload(local_file, remote_file)
          end
        end
      end

################################################################################

      def bootstrap
        raise ProvisionerError, "You must have the environment variable 'USER' set." if !Cucumber::Chef::Config.user

        ZTK::Benchmark.bench(:message => "Bootstrapping #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          chef_client_attributes = {
            "run_list" => %w(recipe[chef-server::rubygems-install] role[test_lab]),
            "cucumber_chef" => {
              "version" => Cucumber::Chef::VERSION,
              "prerelease" => Cucumber::Chef::Config.prerelease
            },
            "lab_user" => Cucumber::Chef.lab_user,
            "lxc_user" => Cucumber::Chef.lxc_user,
            "chef_server" => {
              "webui_enabled" => true
            }
          }

          context = {
            :chef_client_attributes => chef_client_attributes,
            :amqp_password => Cucumber::Chef::Config.chef[:amqp_password],
            :admin_password => Cucumber::Chef::Config.chef[:admin_password],
            :user => Cucumber::Chef::Config.user,
            :hostname_short => Cucumber::Chef.lab_hostname_short,
            :hostname_full => Cucumber::Chef.lab_hostname_full,
            :chef_version => Cucumber::Chef::Config.chef[:version]
          }

          local_bootstrap_file = Tempfile.new("bootstrap")
          local_bootstrap_filename = local_bootstrap_file.path
          local_bootstrap_file.write(::ZTK::Template.render(@bootstrap_template, context))
          local_bootstrap_file.close

          remote_bootstrap_filename = File.join(Cucumber::Chef.lab_user_home_dir, "cucumber-chef-bootstrap.sh")

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

          remote_path = File.join(Cucumber::Chef.lab_user_home_dir, ".chef")
          @ui.logger.debug { "remote_path == #{remote_path.inspect}" }

          files = [ File.basename(Cucumber::Chef.chef_identity), "validation.pem" ]
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

          files = { "id_rsa" => "id_rsa-#{@test_lab.bootstrap_ssh.config.user}" }
          files.each do |remote_file, local_file|
            local = File.join(local_path, local_file)
            File.exists?(local) and File.delete(local)
            @test_lab.bootstrap_ssh.download(File.join(remote_path, remote_file), local)
            File.chmod(0600, local)
          end
        end
      end

################################################################################

      def wait_for_chef_server
        ZTK::Benchmark.bench(:message => "Waiting for the chef-server", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 4000, :data => "GET", :wait => 120).wait
        end

        ZTK::Benchmark.bench(:message => "Waiting for the chef-server-webui", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 4040, :data => "GET", :wait => 120).wait
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
