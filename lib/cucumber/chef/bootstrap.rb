################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
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

################################################################################
