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

      class AWSError < Error; end

      class AWS
        attr_accessor :connection, :server

        INVALID_STATES = %w(terminated pending).map(&:to_sym)
        RUNNING_STATES =  %w(running starting-up).map(&:to_sym)
        SHUTDOWN_STATES = %w(shutdown stopping stopped shutting-down).map(&:to_sym)
        VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

################################################################################

        def initialize(ui=ZTK::UI.new)
          @ui = ui

          @connection = Fog::Compute.new(
            :provider => 'AWS',
            :aws_access_key_id => Cucumber::Chef::Config.aws[:aws_access_key_id],
            :aws_secret_access_key => Cucumber::Chef::Config.aws[:aws_secret_access_key],
            :region => Cucumber::Chef::Config.aws[:region]
          )
          ensure_security_group

          @server = filter_servers(@connection.servers, VALID_STATES)
        end

################################################################################
# CREATE
################################################################################

        def create
          if (exists? && alive?)
            @ui.stdout.puts("A test lab already exists using the #{Cucumber::Chef::Config.provider.upcase} credentials you have supplied; attempting to reprovision it.")
          else
            server_definition = {
              :image_id => Cucumber::Chef::Config.aws_image_id,
              :groups => Cucumber::Chef::Config.aws[:aws_security_group],
              :flavor_id => Cucumber::Chef::Config.aws[:aws_instance_type],
              :key_name => Cucumber::Chef::Config.aws[:aws_ssh_key_id],
              :availability_zone => Cucumber::Chef::Config.aws[:availability_zone],
              :tags => { "purpose" => "cucumber-chef", "cucumber-chef-mode" => Cucumber::Chef::Config.mode },
              :identity_file => Cucumber::Chef::Config.aws[:identity_file]
            }

            if (@server = @connection.servers.create(server_definition))
              ZTK::Benchmark.bench(:message => "Creating #{Cucumber::Chef::Config.provider.upcase} instance", :mark => "completed in %0.4f seconds.", :ui => @ui) do
                @server.wait_for { ready? }
                tag_server
                ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
              end
            end
          end

          self

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { "Backtrace:\n#{e.backtrace.join("\n")}" }
          raise AWSError, e.message
        end

################################################################################
# DESTROY
################################################################################

        def destroy
          if exists?
            @server.destroy
          else
            raise AWSError, "We could not find a test lab!"
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise AWSError, e.message
        end

################################################################################
# UP
################################################################################

        def up
          if (exists? && dead?)
            if @server.start
              @server.wait_for { ready? }
              ZTK::TCPSocketCheck.new(:host => self.ip, :port => self.port, :wait => 120).wait
            else
              raise AWSError, "Failed to boot the test lab!"
            end
          else
            raise AWSError, "We could not find a powered off test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise AWSError, e.message
        end

################################################################################
# HALT
################################################################################

        def down
          if (exists? && alive?)
            if !@server.stop
              raise AWSError, "Failed to halt the test lab!"
            end
          else
            raise AWSError, "We could not find a running test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise AWSError, e.message
        end

################################################################################
# RELOAD
################################################################################

        def reload
          if (exists? && alive?)
            if !@server.restart
              raise AWSError, "Failed to reload the test lab!"
            end
          else
            raise AWSError, "We could not find a running test lab."
          end

        rescue Exception => e
          @ui.logger.fatal { e.message }
          @ui.logger.fatal { e.backtrace.join("\n") }
          raise AWSError, e.message
        end

################################################################################

        def exists?
          !!@server
        end

        def alive?
          (exists? && RUNNING_STATES.include?(self.state))
        end

        def dead?
          (exists? && SHUTDOWN_STATES.include?(self.state))
        end

################################################################################

        def id
          @server.id
        end

        def state
          @server.state.to_sym
        end

        def username
          @server.username
        end

        def ip
          @server.public_ip_address
        end

        def port
          22
        end


################################################################################
    private
################################################################################

        def filter_servers(servers, states=VALID_STATES)
          @ui.logger.debug("states") { states.collect{ |s| s.inspect }.join(", ") }
          results = servers.select do |server|
            @ui.logger.debug("candidate") { "id=#{server.id.inspect}, state=#{server.state.inspect}, tags=#{server.tags.inspect}" }

            ( server.tags['cucumber-chef-mode'] == Cucumber::Chef::Config.mode.to_s &&
              server.tags['cucumber-chef-user'] == Cucumber::Chef::Config.user.to_s &&
              states.any?{ |state| state.to_s == server.state } )
          end
          results.each do |server|
            @ui.logger.debug("results") { "id=#{server.id.inspect}, state=#{server.state.inspect}" }
          end
          results.first
        end

################################################################################

        def tag_server
          {
            "cucumber-chef-mode" => Cucumber::Chef::Config.mode,
            "cucumber-chef-user" => Cucumber::Chef::Config.user,
            "Name" => "cucumber-chef-#{Cucumber::Chef::Config.user}",
            "purpose" => "cucumber-chef"
          }.each do |k, v|
            tag = @connection.tags.new
            tag.resource_id = @server.id
            tag.key, tag.value = k, v
            tag.save
          end
        end

################################################################################

        def ensure_security_group
          security_group_name = Cucumber::Chef::Config.aws[:aws_security_group]
          if (security_group = @connection.security_groups.get(security_group_name))
            port_ranges = security_group.ip_permissions.collect{ |entry| entry["fromPort"]..entry["toPort"] }
            security_group.authorize_port_range(22..22) if port_ranges.none?{ |port_range| port_range === 22 }
            security_group.authorize_port_range(443..443) if port_ranges.none?{ |port_range| port_range === 443 }
            security_group.authorize_port_range(444..444) if port_ranges.none?{ |port_range| port_range === 444 }
          elsif (security_group = @connection.security_groups.new(:name => security_group_name, :description => "cucumber-chef test lab")).save
            security_group.authorize_port_range(22..22)
            security_group.authorize_port_range(443..443)
            security_group.authorize_port_range(444..444)
          else
            raise AWSError, "Could not find an existing or create a new AWS security group."
          end
        end

################################################################################

      end

    end
  end
end

################################################################################
