require "digest"

module Cucumber
  module Chef
    class ProvisionerError < Error ; end

    class Provisioner
      def initialize
        @cookbook_path = File.join(File.dirname(__FILE__), "../../../cookbooks/cucumber-chef")
      end

      def bootstrap_node(dns_name, config)
        template_file = File.join(File.dirname(__FILE__), "templates/ubuntu10.04-gems.erb")
        bootstrap = ::Chef::Knife::Bootstrap.new
        @stdout, @stderr, @stdin = StringIO.new, StringIO.new, StringIO.new
        ui = ::Chef::Knife::UI.new(@stdout, @stderr, @stdin, bootstrap.config)
        bootstrap.ui = ui
        nodename = chef_node_name(config)
        bootstrap.name_args = [dns_name]
        bootstrap.config[:run_list] = "role[test_lab_test]"
        bootstrap.config[:ssh_user] = "ubuntu"
        bootstrap.config[:identity_file] = config[:knife][:identity_file]
        bootstrap.config[:chef_node_name] = nodename
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:template_file] = template_file
        bootstrap.config[:validation_client_name] = config["validation_client_name"]
        bootstrap.config[:validation_key] = config["validation_key"]
        bootstrap.config[:chef_server_url] = config["chef_server_url"]
        bootstrap.run
        tag_node(config)
      end

      def build_controller(dns_name, config)
        template_file = File.join(File.dirname(__FILE__), "templates/controller.erb")
        bootstrap = ::Chef::Knife::Bootstrap.new
        @stdout, @stderr, @stdout = StringIO.new, StringIO.new, StringIO.new
        ui = ::Chef::Knife::UI.new(@stdout, @stderr, @stdout, bootstrap.config)
        bootstrap.ui = ui
        bootstrap.name_args = [dns_name]
        bootstrap.config[:ssh_user] = "ubuntu"
        bootstrap.config[:identity_file] = config[:knife][:identity_file]
        bootstrap.config[:chef_node_name] = "cucumber-chef-controller"
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:template_file] = template_file
        bootstrap.config[:validation_client_name] = config["validation_client_name"]
        bootstrap.config[:validation_key] = config["validation_key"]
        bootstrap.config[:chef_server_url] = config["chef_server_url"]
        bootstrap.run
        bootstrap
      end

      def upload_cookbook(config)
        version_loader = ::Chef::Cookbook::CookbookVersionLoader.new(@cookbook_path)
        version_loader.load_cookbooks
        uploader = ::Chef::CookbookUploader.new(version_loader.cookbook_version,
                                                @cookbook_path)
        uploader.upload_cookbook
      end

      def upload_role(config)
        role_path = File.join(@cookbook_path, "roles")
        ::Chef::Config[:role_path] = role_path
        role = ::Chef::Role.from_disk("test_lab_test")
        role.save
        role = ::Chef::Role.from_disk("controller")
        role.save
      end
      
      def build_test_lab(config, output)
        TestLab.new(config).build(output)
      end

      def tag_node(config)
        node = ::Chef::Node.load(chef_node_name)
        node.tags << (config.test_mode? ? 'test' : 'user')
        node.save
      end
      
    private
      
      def chef_node_name(config=nil)
        @node_name ||= begin
          if config.test_mode?
            "cucumber-chef-#{Digest::SHA1.hexdigest(Time.now.to_s)[0..7]}"
          else
            "cucumber-chef-test-lab"
          end
        end
      end
    end
  end
end
