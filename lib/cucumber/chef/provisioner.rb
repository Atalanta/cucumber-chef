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
        bootstrap
        wait_for_chef_server

        download_chef_credentials

        upload_cookbook
        upload_role
        tag_node
        add_node_role

        chef_first_run

        download_proxy_ssh_credentials

        reboot_test_lab
      end


################################################################################
    private
################################################################################

      def bootstrap
        raise ProvisionerError, "You must have the environment variable 'USER' set." if !Cucumber::Chef::Config.user

        ZTK::Benchmark.bench(:message => "Bootstrapping #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          chef_client_attributes = {
            "run_list" => "role[test_lab]",
            "cucumber_chef" => {
              "version" => Cucumber::Chef::VERSION,
              "prerelease" => Cucumber::Chef::Config.prerelease
            },
            "lab_user" => Cucumber::Chef.lab_user,
            "lxc_user" => Cucumber::Chef.lxc_user
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
          remote_path = File.join(Cucumber::Chef.lab_user_home_dir, ".chef")

          files = [ File.basename(Cucumber::Chef.chef_identity), "validation.pem" ]
          files.each do |file|
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

      def upload_cookbook
        @ui.logger.debug { "Uploading cucumber-chef cookbooks..." }
        ZTK::Benchmark.bench(:message => "Uploading 'cucumber-chef' cookbooks", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          @test_lab.knife_cli(%Q{cookbook upload cucumber-chef -o #{@cookbooks_path}}, :silence => true)
        end
      end

################################################################################

      def upload_role
        @ui.logger.debug { "Uploading cucumber-chef test lab role..." }
        ZTK::Benchmark.bench(:message => "Uploading 'cucumber-chef' roles", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          @test_lab.knife_cli(%Q{role from file #{File.join(@roles_path, "test_lab.rb")}}, :silence => true)
        end
      end

################################################################################

      def tag_node
        @ui.logger.debug { "Tagging cucumber-chef test lab node..." }
        ZTK::Benchmark.bench(:message => "Tagging 'cucumber-chef' node", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          @test_lab.knife_cli(%Q{tag create #{Cucumber::Chef.lab_hostname_full} #{Cucumber::Chef::Config.mode}}, :silence => true)
        end
      end

################################################################################

      def add_node_role
        @ui.logger.debug { "Setting up cucumber-chef test lab run list..." }
        ZTK::Benchmark.bench(:message => "Setting 'cucumber-chef' run list", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          @test_lab.knife_cli(%Q{node run_list add #{Cucumber::Chef.lab_hostname_full} "role[test_lab]"}, :silence => true)
        end
      end

################################################################################

      def chef_first_run
        ZTK::Benchmark.bench(:message => "Performing chef-client run", :mark => "completed in %0.4f seconds.", :ui => @ui) do
          command = "/usr/bin/chef-client -j /etc/chef/first-boot.json -l debug"
          command = "sudo #{command}"
          @test_lab.bootstrap_ssh.exec(command, :silence => true)
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
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => @test_lab.port, :wait => 120).wait
        end

        wait_for_chef_server
      end

    end

  end
end

################################################################################
