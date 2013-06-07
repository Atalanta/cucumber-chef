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

        INVALID_STATES      = %w(not_created aborted unknown).map(&:to_sym)
        RUNNING_STATES      = %w(running).map(&:to_sym)
        SHUTDOWN_STATES     = %w(paused saved poweroff).map(&:to_sym)
        VALID_STATES        = (RUNNING_STATES + SHUTDOWN_STATES)

        MSG_NO_RUNNING_LAB  = %(We could not find a running test lab.)
        MSG_NO_STOPPED_LAB  = %(We could not find a powered off test lab.)
        MSG_NO_LAB          = %(We could not find a test lab!)

################################################################################

        def initialize(ui=ZTK::UI.new)
          @ui = ui
        end

################################################################################
# CREATE
################################################################################

        def create
          ZTK::Benchmark.bench(:message => "Creating #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :stdout => @stdout) do
            context               = build_create_context
            vagrantfile_template  = File.join(Cucumber::Chef.root_dir, "lib", "cucumber", "chef", "templates", "cucumber-chef", "Vagrantfile.erb")
            vagrantfile           = File.join(Cucumber::Chef.chef_repo, "Vagrantfile")

            if !File.exists?(vagrantfile)
              IO.write(vagrantfile, ::ZTK::Template.render(vagrantfile_template, context))
            end

            self.vagrant_cli("up", id)
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
          end

          self
        end

        def build_create_context
          {
            :ip => Cucumber::Chef.lab_ip,
            :cpus => Cucumber::Chef::Config.vagrant[:cpus],
            :memory => Cucumber::Chef::Config.vagrant[:memory]
          }
        end

################################################################################
# DESTROY
################################################################################

        def destroy
          if self.exists?
            self.vagrant_cli("destroy", "--force", id)
          else
            raise VagrantError, MSG_NO_LAB
          end
        end

################################################################################
# UP
################################################################################

        def up
          if self.dead?
            self.vagrant_cli("up", id)
            ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
          else
            raise VagrantError, MSG_NO_STOPPED_LAB
          end
        end

################################################################################
# HALT
################################################################################

        def down
          if self.alive?
            self.vagrant_cli("halt", id)
          else
            raise VagrantError, MSG_NO_RUNNING_LAB
          end
        end

################################################################################
# RELOAD
################################################################################

        def reload
          if self.alive?
            self.vagrant_cli("reload", id)
          else
            raise VagrantError, MSG_NO_RUNNING_LAB
          end
        end

################################################################################

        def exists?
          (self.state != :not_created)
        end

        def alive?
          (self.exists? && (RUNNING_STATES.include?(self.state) rescue false))
        end

        def dead?
          (self.exists? && (SHUTDOWN_STATES.include?(self.state) rescue true))
        end

################################################################################

        def id
          "test-lab-#{ENV['USER']}".downcase
        end

        def state
          output = self.vagrant_cli("status").output.split("\n").grep(/#{id}/)
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
          "vagrant"
        end

        def ip
          "192.168.33.10"
        end

        def port
          22
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
