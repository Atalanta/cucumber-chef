require "erubis"

module Cucumber
  module Chef
    class BootstrapError < Error ; end

    class Bootstrap
      attr_accessor :stdout, :stderr, :stdin, :config

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @ssh = Cucumber::Chef::SSH.new(stdout, stderr, stdin)
        @config = Hash.new(nil)
        @config[:context] = Hash.new(nil)
      end

      def run
        raise BootstrapError, "you must supply a 'template_file'" if !@config[:template_file]

        @ssh.config[:host] = @config[:host]
        @ssh.config[:ssh_user] = @config[:ssh_user]
        @ssh.config[:ssh_password] = @config[:ssh_password]
        @ssh.config[:identity_file] = @config[:identity_file]
        @ssh.config[:timeout] = 5

        command = render_template(load_template(@config[:template_file]), @config[:context])
        command = "sudo #{command}" if @config[:use_sudo]

        begin
          @ssh.exec(command)
        end
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
