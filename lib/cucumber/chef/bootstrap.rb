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
        raise BootstrapError, "You must supply a 'template_file' option." if !@config[:template_file]
        raise BootstrapError, "You must supply a 'host' option." if !@config[:host]
        raise BootstrapError, "You must supply a 'ssh_user' option." if !@config[:ssh_user]
        raise BootstrapError, "You must supply a 'ssh_password' or 'identity_file' option." if (!@config[:ssh_password] && !@config[:identity_file])

        $logger.debug { "Preparing bootstrap for '#{@config[:host]}'." }
        @ssh.config[:host] = @config[:host]
        @ssh.config[:ssh_user] = @config[:ssh_user]
        @ssh.config[:ssh_password] = @config[:ssh_password]
        @ssh.config[:identity_file] = @config[:identity_file]
        @ssh.config[:timeout] = 5

        $logger.debug { "Using template_file '#{@config[:template_file]}'." }
        command = Cucumber::Chef::Template.render(@config[:template_file], @config[:context])
        command = "sudo #{command}" if @config[:use_sudo]

        $logger.debug { "Running bootstrap for '#{@config[:host]}'." }
        @ssh.exec(command, :silence => true)
        $logger.debug { "Finished bootstrap for '#{@config[:host]}'." }
      end

    end

  end
end
