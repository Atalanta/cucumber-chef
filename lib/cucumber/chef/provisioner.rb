################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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
      attr_accessor :stdout, :stderr, :stdin

      HOSTNAME = "cucumber-chef.test-lab"
      PASSWORD = "p@ssw0rd1"

################################################################################

      def initialize(server, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @server = server
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @ssh = ZTK::SSH.new(:stdout => @stdout, :stderr => @stderr, :stdin => @stdin)
        @ssh.config.host_name = @server.public_ip_address
        @ssh.config.user = "ubuntu"
        @ssh.config.keys = Cucumber::Chef::Config[:aws][:identity_file]

        @command = Cucumber::Chef::Command.new(@stdout, @stderr, @stdin)

        @cookbooks_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "chef_repo", "cookbooks"))
        @roles_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "chef_repo", "roles"))
      end

################################################################################

      def build
        template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "templates", "bootstrap", "ubuntu-precise-test-lab.erb"))

        bootstrap(template_file)
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

      def bootstrap(template_file)
        raise ProvisionerError, "You must have the environment variable 'USER' set." if !Cucumber::Chef::Config[:user]

        @stdout.print("Bootstrapping AWS EC2 instance...")
        Cucumber::Chef.spinner do
          attributes = {
            "run_list" => "role[test_lab]",
            "cucumber_chef" => {
              "version" => Cucumber::Chef::VERSION,
              "prerelease" => Cucumber::Chef::Config[:prerelease]
            }
          }

          bootstrap = Cucumber::Chef::Bootstrap.new(@stdout, @stderr, @stdin)
          bootstrap.config[:host] = @server.public_ip_address
          bootstrap.config[:ssh_user] = "ubuntu"
          bootstrap.config[:use_sudo] = true
          bootstrap.config[:identity_file] = Cucumber::Chef::Config[:aws][:identity_file]
          bootstrap.config[:template_file] = template_file
          bootstrap.config[:context][:hostname] = HOSTNAME
          bootstrap.config[:context][:chef_server] = HOSTNAME
          bootstrap.config[:context][:amqp_password] = PASSWORD
          bootstrap.config[:context][:admin_password] = PASSWORD
          bootstrap.config[:context][:user] = Cucumber::Chef::Config[:user]
          bootstrap.config[:context][:attributes] = attributes
          bootstrap.run
        end
        @stdout.print("done.\n")
      end

################################################################################

      def download_chef_credentials
        @stdout.print("Downloading chef-server credentials...")
        Cucumber::Chef.spinner do
          local_path = Cucumber::Chef.locate(:directory, ".cucumber-chef")
          remote_path = File.join("/", "home", @ssh.config[:ssh_user], ".chef")

          files = [ "#{Cucumber::Chef::Config[:user]}.pem", "validation.pem" ]
          files.each do |file|
            @ssh.download(File.join(remote_path, file), File.join(local_path, file))
          end
        end
        @stdout.print("done.\n")
      end

################################################################################

      def download_proxy_ssh_credentials
        @stdout.print("Downloading container SSH credentials...")
        Cucumber::Chef.spinner do
          local_path = Cucumber::Chef.locate(:directory, ".cucumber-chef")
          remote_path = File.join("/", "home", @ssh.config[:ssh_user], ".ssh")

          files = { "id_rsa" => "id_rsa-ubuntu" }
          files.each do |remote_file, local_file|
            local = File.join(local_path, local_file)
            @ssh.download(File.join(remote_path, remote_file), local)
            File.chmod(0600, local)
          end
        end
        @stdout.print("done.\n")
      end

################################################################################

      def render_knife_rb
        @stdout.print("Building 'cc-knife' configuration...")
        Cucumber::Chef.spinner do
          template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "templates", "cucumber-chef", "knife-rb.erb"))
          knife_rb = File.expand_path(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "knife.rb"))

          context = {
            :chef_server => @server.public_ip_address,
            :librarian_chef => Cucumber::Chef::Config[:librarian_chef],
            :user => Cucumber::Chef::Config[:user]
          }

          File.open(knife_rb, 'w') do |f|
            f.puts(Cucumber::Chef::Template.render(template_file, context))
          end
        end
        @stdout.print("done.\n")
      end

################################################################################

      def upload_cookbook
        $logger.debug { "Uploading cucumber-chef cookbooks..." }
        @stdout.print("Uploading cucumber-chef cookbooks...")

        Cucumber::Chef.spinner do
          Cucumber::Chef.load_knife_config
          cookbook_repo = ::Chef::CookbookLoader.new(@cookbooks_path)
          cookbook_repo.each do |name, cookbook|
            $logger.debug { "::Chef::CookbookUploader(#{name}) ATTEMPT" }
            ::Chef::CookbookUploader.new(cookbook, @cookbooks_path, :force => true).upload_cookbooks
            $logger.debug { "::Chef::CookbookUploader(#{name}) UPLOADED" }
          end
          #@command.knife([ "cookbook upload cucumber-chef", "-o", @cookbooks_path ], :silence => true)
        end

        @stdout.print("done.\n")
        $logger.debug { "Successfully uploaded cucumber-chef test lab cookbooks." }
      end

################################################################################

      def upload_role
        $logger.debug { "Uploading cucumber-chef test lab role..." }
        @stdout.print("Uploading cucumber-chef test lab role...")

        Cucumber::Chef.spinner do
          Cucumber::Chef.load_knife_config
          ::Chef::Config[:role_path] = @roles_path
          [ "test_lab" ].each do |name|
            role = ::Chef::Role.from_disk(name)
            role.save
          end
          #@command.knife([ "role from file", File.join(@roles_path, "test_lab.rb") ], :silence => true)
        end

        @stdout.print("done.\n")
        $logger.debug { "Successfully uploaded cucumber-chef test lab roles."}
      end

################################################################################

      def tag_node
        $logger.debug { "Tagging cucumber-chef test lab node..." }
        @stdout.print("Tagging cucumber-chef test lab node...")

        Cucumber::Chef.spinner do
          Cucumber::Chef.load_knife_config
          node = ::Chef::Node.load(HOSTNAME)
          [ Cucumber::Chef::Config[:mode].to_s, Cucumber::Chef::Config[:user].to_s ].each do |tag|
            node.tags << tag
            node.save
          end
          #@command.knife([ "tag create", HOSTNAME, Cucumber::Chef::Config[:mode] ], :silence => true)
        end

        @stdout.print("done.\n")
        $logger.debug { "Successfully tagged cucumber-chef test lab node."}
      end

################################################################################

      def add_node_role
        $logger.debug { "Setting up cucumber-chef test lab run list..." }
        @stdout.print("Setting up cucumber-chef test lab run list...")

        Cucumber::Chef.spinner do
          Cucumber::Chef.load_knife_config
          node = ::Chef::Node.load(HOSTNAME)
          [ "role[test_lab]" ].each do |entry|
            node.run_list << entry
          end
          node.save
          #@command.knife([ "node run_list add", HOSTNAME, "\"role[test_lab]\"" ], :silence => true)
        end

        $logger.debug { "Successfully added roles to cucumber-chef test lab."}
        @stdout.print("done.\n")
      end

################################################################################

      def chef_first_run
        @stdout.print("Performing chef-client run to setup and configure the cucumber-chef test lab...")
        Cucumber::Chef.spinner do
          command = "/usr/bin/chef-client -j /etc/chef/first-boot.json -l debug"
          command = "sudo #{command}"
          @ssh.exec(command, :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def wait_for_chef_server
        @stdout.print("Waiting for Chef-Server...")
        Cucumber::Chef.spinner do
          Cucumber::Chef::TCPSocket.new(@server.public_ip_address, 4000, "GET").wait
        end
        @stdout.puts("done.\n")

        @stdout.print("Waiting for Chef-WebUI...")
        Cucumber::Chef.spinner do
          Cucumber::Chef::TCPSocket.new(@server.public_ip_address, 4040, "GET").wait
        end
        @stdout.puts("done.\n")
      end

################################################################################

      def reboot_test_lab
        @stdout.print("Rebooting test lab; please wait...")
        Cucumber::Chef.spinner do
          command = "sudo reboot"
          @ssh.exec(command, :silence => true)
          sleep(10)
        end
        @stdout.print("done.\n")

        @stdout.print("Waiting for SSHD...")
        Cucumber::Chef.spinner do
          Cucumber::Chef::TCPSocket.new(@server.public_ip_address, 22).wait
        end
        @stdout.puts("done.\n")

        wait_for_chef_server
      end

    end

  end
end

################################################################################
