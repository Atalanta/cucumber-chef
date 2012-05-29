require "digest"

module Cucumber
  module Chef
    class ProvisionerError < Error; end

    class Provisioner
      attr_accessor :stdout, :stderr, :stdin

      def initialize(config, server, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @config = config
        @server = server
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true

        @cookbooks_path = Pathname.new(File.join(File.dirname(__FILE__), "../../../cookbooks/"))
        @roles_path = Pathname.new(File.join(File.dirname(__FILE__), "../../../roles/"))
      end

      def build
        template_file = File.join(File.dirname(__FILE__), "../../../lib/cucumber/chef/bootstrap/ubuntu-chef-server.erb")
        template_file = Pathname.new(template_file).expand_path

        bootstrap(template_file)
        download_credentials
        upload_cookbook
        upload_role
        tag_node
      end


    private

      def run_command(command)
        command = "#{command} 2>&1"
        @stdout.puts("run_command(#{command})")
        @stdout.puts(%x(#{command}))
        raise ProvisionerError, "run_command(#{command}) failed! (#{$?})" if ($? != 0)
      end

      def knife_command(*args)
        "knife #{args.join(" ")} -u ubuntu -k .cucumber-chef/ubuntu.pem -s http://#{@server.public_ip_address}:4000 --color -n"
      end

      def bootstrap(template_file)
        bootstrap = Cucumber::Chef::Bootstrap.new(@stdout, @stderr, @stdin)
        bootstrap.config[:host] = @server.public_ip_address
        bootstrap.config[:ssh_user] = "ubuntu"
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:identity_file] = @config[:knife][:identity_file]
        bootstrap.config[:template_file] = template_file
        bootstrap.config[:context][:hostname] = "cucumber-chef-test-lab"
        bootstrap.config[:context][:chef_server] = @server.public_ip_address
        bootstrap.config[:context][:amqp_password] = "p@ssw0rd1"
        bootstrap.config[:context][:admin_password] = "p@ssw0rd1"
        bootstrap.run
      end

      def download_credentials
        ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        ssh.config[:host] = @server.public_ip_address
        ssh.config[:ssh_user] = "ubuntu"
        ssh.config[:identity_file] = @config[:knife][:identity_file]
        local_path = File.join(Dir.pwd, ".cucumber-chef")
        remote_path = "/home/#{ssh.config[:ssh_user]}/.chef"

        FileUtils.mkdir_p(local_path)

        files = [ "#{ssh.config[:ssh_user]}.pem" ]
        files.each do |file|
          ssh.download(File.join(remote_path, file), File.join(local_path, file))
        end
      end

      def upload_cookbook
        run_command(knife_command("cookbook upload cucumber-chef", "-o", @cookbooks_path.expand_path))
      end

      def upload_role
        run_command(knife_command("role from file", @roles_path.join("test_lab.rb").expand_path))
      end

      def tag_node
        run_command(knife_command("tag create cucumber-chef-test-lab", @config.mode))
      end

    end
  end
end
