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
        attr_accessor :vagrant, :stdout, :stderr, :stdin, :logger

################################################################################

        def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
          @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
          @stdout.sync = true if @stdout.respond_to?(:sync=)

          @vagrant = ::Vagrant::Environment.new
        end

################################################################################

        def create
          @vagrant.cli("up")

          self
        end

        def destroy
          @vagrant.cli("destroy", "--force")
        end

        def start
          @vagrant.cli("up")
        end

        def stop
          @vagrant.cli("suspend")
        end

        def info
          if lab_exists?
            # labs.each do |lab|
            lab = @vagrant.primary_vm
              @stdout.puts("Instance ID: #{lab.name}")
              # @stdout.puts("State: #{lab.state}")
              @stdout.puts("Username: #{lab.config.ssh.username}")
              if lab.config.ssh.host
                @stdout.puts
                @stdout.puts("IP Address..: #{lab.config.ssh.host}")
              end
              # if (lab.dns_name || lab.private_dns_name)
              #   @stdout.puts
              #   @stdout.puts("DNS:")
              #   @stdout.puts("  Public...: #{lab.dns_name}") if lab.dns_name
              #   @stdout.puts("  Private..: #{lab.private_dns_name}") if lab.private_dns_name
              # end
              # if (lab.tags.count > 0)
              #   @stdout.puts
              #   @stdout.puts("Tags:")
              #   lab.tags.to_hash.each do |k,v|
              #     @stdout.puts("  #{k}: #{v}")
              #   end
              # end
              if lab.config.ssh.host
                @stdout.puts
                @stdout.puts("Chef-Server WebUI:")
                @stdout.puts("  http://#{lab.config.ssh.host}:4040/")
              end
              @stdout.puts
            # end
          else
            @stdout.puts("There are no cucumber-chef test labs to display information for!")
          end

        rescue Exception => e
          Cucumber::Chef.logger.fatal { e.message }
          Cucumber::Chef.logger.fatal { e.backtrace.join("\n") }
          raise VagrantError, e.message
        end

        def lab_exists?
          (@vagrant.vms.count > 0)
        end

        def labs
          @vagrant.vms
        end

        def labs_running
          @vagrant.vms
        end

        def labs_shutdown
          Array.new # @vagrant.vms
        end

        def public_ip
          @vagrant.primary_vm.config.ssh.host
        end

        def private_ip
          @vagrant.primary_vm.config.ssh.host
        end

################################################################################

        def ip
          @vagrant.primary_vm.config.ssh.host
        end

################################################################################

        def ssh_port
          @vagrant.primary_vm.config.vm.forwarded_ports.select{ |fwd_port| (fwd_port[:name] == "ssh") }.first[:hostport].to_i
        end

################################################################################

      end

    end
  end
end

################################################################################
