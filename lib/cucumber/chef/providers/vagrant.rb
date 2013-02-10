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
        # attr_accessor :env, :vm

        INVALID_STATES = %w(not_created aborted unknown).map(&:to_sym)
        RUNNING_STATES =  %w(running).map(&:to_sym)
        SHUTDOWN_STATES = %w(paused saved poweroff).map(&:to_sym)
        VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

################################################################################

        def initialize(ui=ZTK::UI.new)
          @ui = ui

          # @env = ::Vagrant::Environment.new
          # @vm = @env.primary_vm
        end

################################################################################
# CREATE
################################################################################

        def create
          ZTK::Benchmark.bench(:message => "Creating #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :stdout => @stdout) do
            self.vagrant_cli("up")
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
          end

          self

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# DESTROY
################################################################################

        def destroy
          if exists?
            self.vagrant_cli("destroy", "--force")
          else
            raise VagrantError, "We could not find a test lab!"
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# UP
################################################################################

        def up
          if (exists? && dead?)
            self.vagrant_cli("up")
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
          else
            raise VagrantError, "We could not find a powered off test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# HALT
################################################################################

        def halt
          if (exists? && alive?)
            self.vagrant_cli("halt")
          else
            raise AWSError, "We could not find a running test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################
# RELOAD
################################################################################

        def reload
          if (exists? && alive?)
            self.vagrant_cli("reload")
          else
            raise AWSError, "We could not find a running test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

################################################################################

        def exists?
          (self.state != :not_created)
        end

        def alive?
          (RUNNING_STATES.include?(self.state) rescue false)
        end

        def dead?
          (SHUTDOWN_STATES.include?(self.state) rescue true)
        end

################################################################################

        def id
          # @vm.name
          "default"
        end

        def state
          output = self.vagrant_cli("status | grep '#{id}'").output
          result = :unknown
          (VALID_STATES+INVALID_STATES).each do |state|
            if output =~ /#{state}/
              result = state
              break
            end
          end
          result.to_sym
        end

        def username
          # @vm.config.ssh.username
          "vagrant"
        end

        def ip
          # @vm.config.ssh.host
          "127.0.0.1"
        end

        def port
          # @vm.config.vm.forwarded_ports.select{ |fwd_port| (fwd_port[:name] == "ssh") }.first[:hostport].to_i
          2222
        end

################################################################################

        def vagrant_cli(*args)
          command = Cucumber::Chef.build_command("vagrant", *args)
          ZTK::Command.new.exec(command, :silence => true)
        end

################################################################################

      end

    end
  end
end

################################################################################
