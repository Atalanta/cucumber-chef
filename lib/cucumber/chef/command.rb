################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

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

################################################################################
