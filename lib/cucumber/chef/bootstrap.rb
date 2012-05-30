require "erubis"

module Cucumber
  module Chef
    class BootstrapError < Error; end

    class Bootstrap
      attr_accessor :stdout, :stderr, :stdin, :config

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @config = Hash.new(nil)
        @config[:context] = Hash.new(nil)
      end

      def run
        raise BootstrapError, "you must supply a 'template'" if !@config[:template]
        raise BootstrapError, "you must supply a 'host'" if !@config[:host]
        raise BootstrapError, "you must supply a 'ssh_user'" if !@config[:ssh_user]
        raise BootstrapError, "you must supply a 'ssh_password' or 'identity_file'" if (!@config[:ssh_password] && !@config[:identity_file])

        @stdout.puts("Preparing bootstrap for '#{@config[:host]}'.")
        @ssh.config[:host] = @config[:host]
        @ssh.config[:ssh_user] = @config[:ssh_user]
        @ssh.config[:ssh_password] = @config[:ssh_password]
        @ssh.config[:identity_file] = @config[:identity_file]
        @ssh.config[:timeout] = 5

        @stdout.puts("Using template '#{@config[:template]}'.")
        command = render_template(load_template(@config[:template]), @config[:context])
        command = "sudo #{command}" if @config[:use_sudo]

        @stdout.puts("Running bootstrap for '#{@config[:host]}'.")
        @ssh.exec(command)
        @stdout.puts("Finished bootstrap for '#{@config[:host]}'.")
      end


    private

      def load_template(template)
        IO.read(template).chomp
      end

      def render_template(template, context)
        Erubis::Eruby.new(template).evaluate(:config => context)
      end

    end
  end
end
