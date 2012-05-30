module Cucumber
  module Chef

    class BootstrapError < Error; end

    class Bootstrap
      attr_accessor :stdout, :stderr, :stdin, :config

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @config = Hash.new(nil)
        @config[:context] = Hash.new(nil)
      end

      def run
        raise BootstrapError("You must supply a 'template' option.") if !@config[:template]
        raise BootstrapError("You must supply a 'host' option.") if !@config[:host]
        raise BootstrapError("You must supply a 'ssh_user' option.") if !@config[:ssh_user]
        raise BootstrapError("You must supply a 'ssh_password' or 'identity_file' option.") if (!@config[:ssh_password] && !@config[:identity_file])

        @stdout.puts("Preparing bootstrap for '#{@config[:host]}'.")
        @ssh.config[:host] = @config[:host]
        @ssh.config[:ssh_user] = @config[:ssh_user]
        @ssh.config[:ssh_password] = @config[:ssh_password]
        @ssh.config[:identity_file] = @config[:identity_file]
        @ssh.config[:timeout] = 5

        @stdout.puts("Using template '#{@config[:template]}'.")
        command = Cucumber::Chef::Template.render(@config[:template], @config[:context])
        command = "sudo #{command}" if @config[:use_sudo]

        @stdout.puts("Running bootstrap for '#{@config[:host]}'.")
        @ssh.exec(command)
        @stdout.puts("Finished bootstrap for '#{@config[:host]}'.")
      end

    end

  end
end
