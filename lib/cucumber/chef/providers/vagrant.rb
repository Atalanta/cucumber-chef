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

################################################################################

        def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
          @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
          @stdout.sync = true if @stdout.respond_to?(:sync=)

          # @env = ::Vagrant::Environment.new
          @env = ::Vagrant::Environment.new(:ui_class => ::Vagrant::UI::Colored)
          @vm = @env.primary_vm
        end

################################################################################

        def create
          @stdout.puts("Provisioning cucumber-chef test lab platform.")

          @stdout.print("Waiting for instance...")
          Cucumber::Chef.spinner do
            @env.cli("up")
          end
          @stdout.puts("done.\n")

          @stdout.print("Waiting for SSHD...")
          Cucumber::Chef.spinner do
            ZTK::TCPSocketCheck.new(:host => self.public_ip, :port => 22, :wait => 120).wait
          end
          @stdout.puts("done.\n")

          self
        end

        def destroy
          @env.cli("destroy", "--force")
        end

        def up
          @env.cli("up")
        end

        def down
          @env.cli("halt")
        end

################################################################################

        def id
          @vm.name
        end

        def state
          @vm.state
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

        def lab_exists?
          (@env.vms.count > 0)
        end

        def labs
          [@env.primary_vm]
        end

        def labs_running
          [@env.primary_vm]
        end

        def labs_shutdown
          Array.new # @env.vms
        end

################################################################################

      end

    end
  end
end

################################################################################
