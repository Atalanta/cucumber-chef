module Cucumber
  module Chef

    class BootstrapError < Error; end

    class Bootstrap
      attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @config = Hash.new(nil)
        @config[:context] = Hash.new(nil)
      end

################################################################################

      def run
        $logger.debug { "config(#{@config.inspect})" }

        if !@config[:template_file]
          message = "You must supply a 'template_file' option."
          $logger.fatal { message }
          raise BootstrapError, message
        end

        if !@config[:host]
          message = "You must supply a 'host' option."
          $logger.fatal { message }
          raise BootstrapError, message
        end

        if !@config[:ssh_user]
          message = "You must supply a 'ssh_user' option."
          $logger.fatal { message }
          raise BootstrapError, message
        end

        if (!@config[:ssh_password] && !@config[:identity_file])
          message = "You must supply a 'ssh_password' or 'identity_file' option."
          $logger.fatal { message }
          raise BootstrapError, message
        end

        $logger.debug { "prepare(#{@config[:host]})" }

        @ssh.config[:host] = @config[:host]
        @ssh.config[:ssh_user] = @config[:ssh_user]
        @ssh.config[:ssh_password] = @config[:ssh_password]
        @ssh.config[:identity_file] = @config[:identity_file]
        @ssh.config[:timeout] = 5

        $logger.debug { "template_file(#{@config[:template_file]})" }
        command = Cucumber::Chef::Template.render(@config[:template_file], @config[:context])
        command = "sudo #{command}" if @config[:use_sudo]

        $logger.debug { "begin(#{@config[:host]})" }
        @ssh.exec(command, :silence => true)
        $logger.debug { "end(#{@config[:host]})" }
      end

################################################################################

    end

  end
end
