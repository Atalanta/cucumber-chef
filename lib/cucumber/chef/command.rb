module Cucumber
  module Chef

    class CommandError < Error; end

    class Command
      attr_accessor :stdout, :stderr, :stdin

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @knife = (Cucumber::Chef.locate(:file, "bin", "knife") rescue nil)
        @knife = "/usr/bin/env knife" unless @knife
      end

################################################################################

      def run(command, options={})
        options = { :exit_code => 0, :silence => false }.merge(options)
        exit_code = options[:exit_code]
        silence = options[:silence]
        $logger.debug { "options(#{options.inspect})" }

        command = "#{command} 2>&1"
        $logger.debug { "command(#{command})" }
        output = %x( #{command} )
        $logger.debug { "exit_code(#{$?})" }

        $logger.debug { "--------------------------------------------------------------------------------" }
        $logger.debug { output }
        $logger.debug { "--------------------------------------------------------------------------------" }

        @stdout.puts(output) if !silence

        raise CommandError, "run(#{command}) failed! [#{$?}]" if ($? != exit_code)

        output
      end

################################################################################

      def knife(command, options={})
        knife_rb = File.expand_path(File.join(Dir.pwd, ".cucumber-chef", "knife.rb"))
        run("#{@knife} #{command.flatten.compact.join(" ")} -c #{knife_rb}  --color -n", options)
      end

################################################################################

    end

  end
end
