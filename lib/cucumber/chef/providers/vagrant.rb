################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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
    class Provider

      class VagrantError < Error; end

      class Vagrant
        attr_accessor :env, :vm, :stdout, :stderr, :stdin, :logger

        INVALID_STATES = %w(terminated pending).map(&:to_sym)
        RUNNING_STATES =  %w(running).map(&:to_sym)
        SHUTDOWN_STATES = %w(shutdown stopping stopped shutting-down).map(&:to_sym)
        VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

################################################################################

        def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
          @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
          @stdout.sync = true if @stdout.respond_to?(:sync=)

          @env = ::Vagrant::Environment.new
          # @env = ::Vagrant::Environment.new(:ui_class => ::Vagrant::UI::Colored)
          @vm = @env.primary_vm
        end

################################################################################
# CREATE
################################################################################

        def create
          ZTK::Benchmark.bench("Waiting for #{Cucumber::Chef::Config.provider.upcase} instance", @stdout) do
            @env.cli("up")
          end
          ZTK::Benchmark.bench("Waiting for SSHD", @stdout) do
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => 22, :wait => 120).wait
          end

          self

        rescue Exception => e
          Cucumber::Chef.logger.fatal { e.message }
          Cucumber::Chef.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# DESTROY
################################################################################

        def destroy
          if exists?
            @env.cli("destroy", "--force")
          else
            raise VagrantError, "We could not find a test lab!"
          end

        rescue Exception => e
          Cucumber::Chef.logger.fatal { e.message }
          Cucumber::Chef.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# UP
################################################################################

        def up
          if (exists? && dead?)
            @env.cli("up")
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
          else
            raise VagrantError, "We could not find a powered off test lab."
          end

        rescue Exception => e
          Cucumber::Chef.logger.fatal { e.message }
          Cucumber::Chef.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# HALT
################################################################################

        def halt
          if (exists? && alive?)
            @env.cli("halt")
          else
            raise AWSError, "We could not find a running test lab."
          end

        rescue Exception => e
          Cucumber::Chef.logger.fatal { e.message }
          Cucumber::Chef.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################

        def exists?
          (@env.vms.count > 0)
        end

        def alive?
          (RUNNING_STATES.include?(self.state) rescue false)
        end

        def dead?
          (SHUTDOWN_STATES.include?(self.state) rescue true)
        end

################################################################################

        def id
          @vm.name
        end

        def state
          @vm.state.to_sym
        end

        def username
          @vm.config.ssh.username
        end

        def ip
          @vm.config.ssh.host
        end

        def port
          @vm.config.vm.forwarded_ports.select{ |fwd_port| (fwd_port[:name] == "ssh") }.first[:hostport].to_i
        end

################################################################################

      end

    end
  end
end

################################################################################
