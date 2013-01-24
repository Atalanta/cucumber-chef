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
      attr_accessor :test_lab, :stdout, :stderr, :stdin

      HOSTNAME = "cucumber-chef.test-lab"
      PASSWORD = "p@ssw0rd1"

################################################################################

      def initialize(test_lab, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @test_lab = test_lab

        @cookbooks_path = File.join(Cucumber::Chef.root_dir, "chef_repo", "cookbooks")
        @roles_path = File.join(Cucumber::Chef.root_dir, "chef_repo", "roles")
        @bootstrap_template = File.join(Cucumber::Chef.root_dir, "lib", "cucumber", "chef", "templates", "bootstrap", "ubuntu-precise-test-lab.erb")
      end

################################################################################

      def build
        bootstrap
        wait_for_chef_server

        download_chef_credentials
        render_knife_rb

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

        ZTK::Benchmark.bench("Bootstrapping #{Cucumber::Chef::Config.provider.upcase} instance", :stdout => @stdout) do
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
            :hostname_full => Cucumber::Chef.lab_hostname_full
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
        ZTK::Benchmark.bench("Downloading chef-server credentials", :stdout => @stdout) do
          local_path = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s)
          remote_path = File.join(Cucumber::Chef.lab_user_home_dir, ".chef")

          files = [ "#{Cucumber::Chef::Config[:user]}.pem", "validation.pem" ]
          files.each do |file|
            @test_lab.bootstrap_ssh.download(File.join(remote_path, file), File.join(local_path, file))
          end
        end
      end

################################################################################

      def download_proxy_ssh_credentials
        ZTK::Benchmark.bench("Downloading proxy SSH credentials", :stdout => @stdout) do
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

      def render_knife_rb
        ZTK::Benchmark.bench("Building 'cc-knife' configuration", :stdout => @stdout) do
          template_file = File.join(Cucumber::Chef.root_dir, "lib", "cucumber", "chef", "templates", "cucumber-chef", "knife-rb.erb")

          context = {
            :chef_server => @test_lab.ip,
            :librarian_chef => Cucumber::Chef::Config.librarian_chef,
            :user => Cucumber::Chef::Config.user
          }

          File.open(Cucumber::Chef.knife_rb, 'w') do |f|
            f.puts(ZTK::Template.render(template_file, context))
          end
        end
      end

################################################################################

      def upload_cookbook
        Cucumber::Chef.logger.debug { "Uploading cucumber-chef cookbooks..." }
        ZTK::Benchmark.bench("Uploading 'cucumber-chef' cookbooks", :stdout => @stdout) do
          Cucumber::Chef.load_chef_config
          cookbook_repo = ::Chef::CookbookLoader.new(@cookbooks_path)
          cookbook_repo.each do |name, cookbook|
            Cucumber::Chef.logger.debug { "::Chef::CookbookUploader(#{name}) ATTEMPT" }
            ::Chef::CookbookUploader.new(cookbook, @cookbooks_path, :force => true).upload_cookbooks
            Cucumber::Chef.logger.debug { "::Chef::CookbookUploader(#{name}) UPLOADED" }
          end
          #@command.knife([ "cookbook upload cucumber-chef", "-o", @cookbooks_path ], :silence => true)
        end
      end

################################################################################

      def upload_role
        Cucumber::Chef.logger.debug { "Uploading cucumber-chef test lab role..." }
        ZTK::Benchmark.bench("Uploading 'cucumber-chef' roles", :stdout => @stdout) do
          Cucumber::Chef.load_chef_config
          ::Chef::Config[:role_path] = @roles_path
          [ "test_lab" ].each do |name|
            role = ::Chef::Role.from_disk(name)
            role.save
          end
          #@command.knife([ "role from file", File.join(@roles_path, "test_lab.rb") ], :silence => true)
        end
      end

################################################################################

      def tag_node
        Cucumber::Chef.logger.debug { "Tagging cucumber-chef test lab node..." }
        ZTK::Benchmark.bench("Tagging 'cucumber-chef' node", :stdout => @stdout) do
          Cucumber::Chef.load_chef_config
          node = ::Chef::Node.load(HOSTNAME)
          [ Cucumber::Chef::Config[:mode].to_s, Cucumber::Chef::Config[:user].to_s ].each do |tag|
            node.tags << tag
            node.save
          end
          #@command.knife([ "tag create", HOSTNAME, Cucumber::Chef::Config[:mode] ], :silence => true)
        end
      end

################################################################################

      def add_node_role
        Cucumber::Chef.logger.debug { "Setting up cucumber-chef test lab run list..." }
        ZTK::Benchmark.bench("Setting 'cucumber-chef' run list", :stdout => @stdout) do
          Cucumber::Chef.load_chef_config
          node = ::Chef::Node.load(HOSTNAME)
          [ "role[test_lab]" ].each do |entry|
            node.run_list << entry
          end
          node.save
          #@command.knife([ "node run_list add", HOSTNAME, "\"role[test_lab]\"" ], :silence => true)
        end
      end

################################################################################

      def chef_first_run
        ZTK::Benchmark.bench("Performing chef-client run", :stdout => @stdout) do
          command = "/usr/bin/chef-client -j /etc/chef/first-boot.json -l debug"
          command = "sudo #{command}"
          @test_lab.bootstrap_ssh.exec(command, :silence => true)
        end
      end

################################################################################

      def wait_for_chef_server
        ZTK::Benchmark.bench("Waiting for the chef-server", :stdout => @stdout) do
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 4000, :data => "GET", :wait => 120).wait
        end

        ZTK::Benchmark.bench("Waiting for the chef-server-webui", :stdout => @stdout) do
          ZTK::TCPSocketCheck.new(:host => @test_lab.ip, :port => 4040, :data => "GET", :wait => 120).wait
        end
      end

################################################################################

      def reboot_test_lab
        ZTK::Benchmark.bench("Rebooting the test lab", :stdout => @stdout) do
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
