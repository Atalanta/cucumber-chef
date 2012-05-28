require "digest"

module Cucumber
  module Chef
    class ProvisionerError < Error ; end

    class Provisioner
      attr_accessor :stdout, :stderr, :stdin

      def initialize(config, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @config = config
        @cookbook_path = File.join(File.dirname(__FILE__), "../../../cookbooks/cucumber-chef")
      end

      def bootstrap_node(server)
        template_file = File.join(File.dirname(__FILE__), "bootstrap/ubuntu-#{@config[:knife][:ubuntu_release]}.erb")
        @stdout.puts("Using bootstrap template '#{template_file}'.")
        run_bootstrap(template_file, server, chef_node_name, "role[test_lab]")
        tag_node
      end

      def upload_cookbook
        version_loader = ::Chef::Cookbook::CookbookVersionLoader.new(@cookbook_path)
        version_loader.load_cookbooks
        uploader = ::Chef::CookbookUploader.new(version_loader.cookbook_version, @cookbook_path)
        uploader.validate_cookbook
        uploader.upload_cookbook
      end

      def upload_role
        role_path = File.join(@cookbook_path, "roles")
        ::Chef::Config[:role_path] = role_path
        role = ::Chef::Role.from_disk("test_lab")
        role.save
      end

      def tag_node
        node = ::Chef::Node.load(chef_node_name)
        node.tags << (@config.test_mode? ? :test : :user)
        node.save
      end


    private

      def run_bootstrap(template_file, server, node_name, run_list=nil)
        @stdout.puts("Preparing bootstrap for '#{server.public_ip_address}'.")

        bootstrap = ::Chef::Knife::Bootstrap.new
        ui = ::Chef::Knife::UI.new(@stdout, @stderr, @stdin, bootstrap.config)
        bootstrap.ui = ui
        bootstrap.name_args = [server.public_ip_address]
        bootstrap.config[:run_list] = run_list
        bootstrap.config[:ssh_user] = "ubuntu"
        bootstrap.config[:ssh_password] = "ubuntu"
        bootstrap.config[:identity_file] = @config[:knife][:identity_file]
        bootstrap.config[:chef_node_name] = node_name
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:template_file] = template_file
        bootstrap.config[:validation_client_name] = @config["validation_client_name"]
        bootstrap.config[:validation_key] = @config["validation_key"]
        bootstrap.config[:chef_server_url] = @config["chef_server_url"]
        bootstrap.config[:distro] = "ubuntu-#{@config[:knife][:ubuntu_release]}"
        bootstrap.config[:host_key_verify] = false

        sleep(3)

        @stdout.puts("Running bootstrap for '#{server.public_ip_address}'.")
        bootstrap.run

        @stdout.puts("Finished bootstrapping '#{server.public_ip_address}'.")
        bootstrap
      end

      def chef_node_name
        @node_name ||= begin
          if @config.test_mode?
            "cucumber-chef-#{Digest::SHA1.hexdigest(Time.now.to_s)[0..7]}"
          else
            "cucumber-chef-test-lab"
          end
        end
      end

    end
  end
end
