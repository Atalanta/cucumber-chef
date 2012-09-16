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

    class UtilityError < Error; end

    module Utility

################################################################################

      def is_rc?
        ((Cucumber::Chef::VERSION =~ /rc/) || (Cucumber::Chef::VERSION =~ /pre/))
      end

################################################################################

      def root
        File.expand_path(File.join(File.dirname(__FILE__), "..", "..", ".."), File.dirname(__FILE__))
      end

################################################################################

      def load_knife_config
        $logger.debug { "attempting to load cucumber-chef test lab 'knife.rb'" }

        knife_rb = Cucumber::Chef.locate(:file, ".cucumber-chef", "knife.rb")
        ::Chef::Config.from_file(knife_rb)

        $logger.debug { "load_knife_config(#{knife_rb})" }
      end

################################################################################

      def locate(type, *args)
        pwd = Dir.pwd.split(File::SEPARATOR)
        $logger.debug { "pwd='#{Dir.pwd}'" } if $logger
        (pwd.length - 1).downto(0) do |i|
          candidate = File.join(pwd[0..i], args)
          $logger.debug { "candidate='#{candidate}'" } if $logger
          case type
          when :file
            if (File.exists?(candidate) && !File.directory?(candidate))
              result = File.expand_path(candidate)
              $logger.debug { "result='#{result}'" } if $logger
              return result
            end
          when :directory
            if (File.exists?(candidate) && File.directory?(candidate))
              result = File.expand_path(candidate)
              $logger.debug { "result='#{result}'" } if $logger
              return result
            end
          when :any
            if File.exists?(candidate)
              result = File.expand_path(candidate)
              $logger.debug { "result='#{result}'" } if $logger
              return result
            end
          end
        end

        message = "Could not locate #{type} '#{File.join(args)}'."
        $logger.fatal { message } if $logger
        raise UtilityError, message
      end

################################################################################

      def locate_parent(child)
        parent = (locate(:any, child).split(File::SEPARATOR) rescue nil)
        raise UtilityError, "Could not locate parent of '#{child}'." unless parent
        File.expand_path(File.join(parent[0..(parent.length - 2)]))
      end

################################################################################

      def spinner(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        spinning_chars = %w[| / - \\]
        count = 0
        spinner = Thread.new do
          while count do
            stdout.print spinning_chars[(count+=1) % spinning_chars.length]
            stdout.flush if stdout.respond_to?(:flush)
            sleep(0.25)
            stdout.print "\b"
            stdout.flush if stdout.respond_to?(:flush)
          end
        end
        yield.tap do
          count = false
          spinner.join
        end
      end

################################################################################

      def generate_do_not_edit_warning(message=nil)
        warning = []
        warning << "#"
        warning << "# WARNING: Automatically generated file; DO NOT EDIT!"
        warning << [ "# Cucumber-Chef v#{Cucumber::Chef::VERSION}", message ].compact.join(" ")
        warning << "# Generated on #{Time.now.utc.to_s}"
        warning << "#"
        warning.join("\n")
      end

################################################################################

      def external_ip
        %x( wget -q -O - checkip.dyndns.org|sed -e 's/.*Current IP Address: //' -e 's/<.*$//' ).chomp
      end

################################################################################

    end

  end
end

################################################################################
