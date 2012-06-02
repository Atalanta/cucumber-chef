module Cucumber
  module Chef

    class CommandError < Error; end

    class Command
      attr_accessor :stdout, :stderr, :stdin

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @knife = (Cucumber::Chef.locate(:file, "bin", "knife") rescue nil)
        @knife = "/usr/bin/env knife" unless @knife
      end

      def run(command, exit_code=0)
        command = "#{command} 2>&1"
        output = %x(#{command})

        @stdout.puts("R:[#{command}] (#{$?})")
        @stdout.puts("--------------------------------------------------------------------------------")
        @stdout.puts(output)
        @stdout.puts("--------------------------------------------------------------------------------")

        raise CommandError, "run(#{command}) failed! [#{$?}]" if ($? != exit_code)

        output
      end

      def knife(*args)
        knife_rb = File.expand_path(File.join(Dir.pwd, ".cucumber-chef", "knife.rb"))
        run("#{@knife} #{args.flatten.compact.join(" ")} -c #{knife_rb}  --color -n")
      end

    end

  end
end
