################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
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

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @ssh.config[:host] = @server.public_ip_address
        @ssh.config[:ssh_user] = "ubuntu"
        @ssh.config[:identity_file] = Cucumber::Chef::Config[:aws][:identity_file]

        @command = Cucumber::Chef::Command.new(@stdout, @stderr, @stdin)

        @user = ENV['OPSCODE_USER'] || ENV['USER']
        @cookbooks_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "chef_repo", "cookbooks"))
        @roles_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "chef_repo", "roles"))
      end

################################################################################

      def build
        template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "templates", "bootstrap", "ubuntu-maverick-test-lab.erb"))

        bootstrap(template_file)
        download_chef_credentials
        render_knife_rb

        upload_cookbook
        upload_role
        tag_node
        add_node_role

        chef_first_run

        download_proxy_ssh_credentials
      end


################################################################################
    private
################################################################################

      def bootstrap(template_file)
        raise ProvisionerError, "You must have the environment variable 'USER' set." if !@user

        @stdout.print("Bootstrapping AWS EC2 instance...")
        Cucumber::Chef.spinner do
          attributes = {
            "run_list" => "role[test_lab]",
            "cucumber_chef" => {
              "version" => Cucumber::Chef::VERSION
            }
          }

          bootstrap = Cucumber::Chef::Bootstrap.new(@stdout, @stderr, @stdin)
          bootstrap.config[:host] = @server.public_ip_address
          bootstrap.config[:ssh_user] = "ubuntu"
          bootstrap.config[:use_sudo] = true
          bootstrap.config[:identity_file] = Cucumber::Chef::Config[:aws][:identity_file]
          bootstrap.config[:template_file] = template_file
          bootstrap.config[:context][:hostname] = HOSTNAME
          bootstrap.config[:context][:chef_server] = @server.public_ip_address
          bootstrap.config[:context][:amqp_password] = PASSWORD
          bootstrap.config[:context][:admin_password] = PASSWORD
          bootstrap.config[:context][:user] = @user
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

          files = [ "#{@user}.pem", "validation.pem" ]
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
          template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "templates", "chef", "knife-rb.erb"))
          knife_rb = File.expand_path(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "knife.rb"))

          context = { :chef_server => @server.public_ip_address }
          File.open(knife_rb, 'w') do |f|
            f.puts(Cucumber::Chef::Template.render(template_file, context))
          end
        end
        @stdout.print("done.\n")
      end

################################################################################

      def upload_cookbook
        @stdout.print("Uploading cucumber-chef cookbooks...")
        Cucumber::Chef.spinner do
          @command.knife([ "cookbook upload cucumber-chef", "-o", @cookbooks_path ], :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def upload_role
        @stdout.print("Uploading cucumber-chef test lab role...")
        Cucumber::Chef.spinner do
          @command.knife([ "role from file", File.join(@roles_path, "test_lab.rb") ], :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def tag_node
        @stdout.print("Tagging cucumber-chef test lab node...")
        Cucumber::Chef.spinner do
          @command.knife([ "tag create", HOSTNAME, Cucumber::Chef::Config[:mode] ], :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def add_node_role
        @stdout.print("Setting up cucumber-chef test lab run list...")
        Cucumber::Chef.spinner do
          @command.knife([ "node run_list add", HOSTNAME, "\"role[test_lab]\"" ], :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def chef_first_run
        @stdout.print("Performing chef-client first run on cucumber-chef test lab...")
        Cucumber::Chef.spinner do
          command = "/usr/bin/chef-client -j /etc/chef/first-boot.json -l debug"
          command = "sudo #{command}"
          @ssh.exec(command, :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

    end

  end
end

################################################################################
