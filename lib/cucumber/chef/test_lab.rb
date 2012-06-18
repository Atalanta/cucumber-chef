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

    class TestLabError < Error; end

    class TestLab
      attr_reader :connection, :server
      attr_accessor :stdout, :stderr, :stdin

      INVALID_STATES = %w( terminated pending )
      RUNNING_STATES =  %w( running starting-up )
      SHUTDOWN_STATES = %w( shutdown stopping stopped shutting-down )
      VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @connection = Fog::Compute.new(:provider => 'AWS',
                                       :aws_access_key_id => Cucumber::Chef::Config[:aws][:aws_access_key_id],
                                       :aws_secret_access_key => Cucumber::Chef::Config[:aws][:aws_secret_access_key],
                                       :region => Cucumber::Chef::Config[:aws][:region])
        ensure_security_group
      end

################################################################################

      def create
        if (lab_exists? && (@server = labs_running.first))
          @stdout.puts("A test lab already exists using the AWS credentials you have supplied; attempting to reprovision it.")
        else
          server_definition = {
            :image_id => Cucumber::Chef::Config.aws_image_id,
            :groups => Cucumber::Chef::Config[:aws][:aws_security_group],
            :flavor_id => Cucumber::Chef::Config[:aws][:aws_instance_type],
            :key_name => Cucumber::Chef::Config[:aws][:aws_ssh_key_id],
            :availability_zone => Cucumber::Chef::Config[:aws][:availability_zone],
            :tags => { "purpose" => "cucumber-chef", "cucumber-chef-mode" => Cucumber::Chef::Config[:mode] },
            :identity_file => Cucumber::Chef::Config[:aws][:identity_file]
          }
          if (@server = @connection.servers.create(server_definition))
            @stdout.puts("Provisioning cucumber-chef test lab platform.")

            @stdout.print("Waiting for instance...")
            Cucumber::Chef.spinner do
              @server.wait_for { ready? }
            end
            @stdout.puts("done.\n")

            tag_server

            @stdout.print("Waiting for 20 seconds...")
            Cucumber::Chef.spinner do
              sleep(20)
            end
            @stdout.print("done.\n")
          end
        end

        if @server
          @stdout.print("Waiting for SSHD...")
          Cucumber::Chef.spinner do
            Cucumber::Chef::TCPSocket.new(@server.public_ip_address, 22).wait
          end
          @stdout.puts("done.\n")
        end

        @server

      rescue Exception => e
        $logger.fatal { e.message }
        $logger.fatal { "Backtrace:\n#{e.backtrace.join("\n")}" }
        raise TestLabError, e.message
      end

################################################################################

      def destroy
        if ((l = labs).count > 0)
          @stdout.puts("Destroying Servers:")
          l.each do |server|
            @stdout.puts("  * #{server.public_ip_address}")
            server.destroy
          end
        else
          @stdout.puts("There are no cucumber-chef test labs to destroy!")
        end

      rescue Exception => e
        $logger.fatal { e.message }
        $logger.fatal { e.backtrace.join("\n") }
        raise TestLabError, e.message
      end

################################################################################

      def start
        if (lab_exists? && (@server = labs_shutdown.first))
          if @server.start

            @stdout.print("Waiting for instance...")
            Cucumber::Chef.spinner do
              @server.wait_for { ready? }
            end
            @stdout.puts("done.\n")

            @stdout.print("Waiting for SSHD...")
            Cucumber::Chef.spinner do
              Cucumber::Chef::TCPSocket.new(@server.public_ip_address, 22).wait
            end
            @stdout.puts("done.\n")

            @stdout.puts("Successfully started up cucumber-chef test lab!")

            info
          else
            @stdout.puts("Failed to start up cucumber-chef test lab!")
          end
        else
          @stdout.puts("There are no available cucumber-chef test labs to start up!")
        end

      rescue Exception => e
        $logger.fatal { e.message }
        $logger.fatal { e.backtrace.join("\n") }
        raise TestLabError, e.message
      end


      def stop
        if (lab_exists? && (@server = labs_running.first))
          if @server.stop
            @stdout.puts("Successfully shutdown cucumber-chef test lab!")
          else
            @stdout.puts("Failed to shutdown cucumber-chef test lab!")
          end
        else
          @stdout.puts("There are no available cucumber-chef test labs top shutdown!")
        end

      rescue Exception => e
        $logger.fatal { e.message }
        $logger.fatal { e.backtrace.join("\n") }
        raise TestLabError, e.message
      end

################################################################################

      def info
        if lab_exists?
          labs.each do |lab|
            @stdout.puts("Instance ID: #{lab.id}")
            @stdout.puts("State: #{lab.state}")
            @stdout.puts("Username: #{lab.username}") if lab.username
            if (lab.public_ip_address || lab.private_ip_address)
              @stdout.puts
              @stdout.puts("IP Address:")
              @stdout.puts("  Public...: #{lab.public_ip_address}") if lab.public_ip_address
              @stdout.puts("  Private..: #{lab.private_ip_address}") if lab.private_ip_address
            end
            if (lab.dns_name || lab.private_dns_name)
              @stdout.puts
              @stdout.puts("DNS:")
              @stdout.puts("  Public...: #{lab.dns_name}") if lab.dns_name
              @stdout.puts("  Private..: #{lab.private_dns_name}") if lab.private_dns_name
            end
            if (lab.tags.count > 0)
              @stdout.puts
              @stdout.puts("Tags:")
              lab.tags.to_hash.each do |k,v|
                @stdout.puts("  #{k}: #{v}")
              end
            end
            if lab.public_ip_address
              @stdout.puts
              @stdout.puts("Chef-Server WebUI:")
              @stdout.puts("  http://#{lab.public_ip_address}:4040/")
            end
            @stdout.puts
            if (labs_running.include?(lab) && (n = nodes))
              @stdout.puts
              @stdout.puts("Nodes:")
              n.each do |node|
                @stdout.puts("  * #{node.name} (#{node.cloud.public_ipv4})")
              end
            end
            if (labs_running.include?(lab) && (c = clients))
              @stdout.puts
              @stdout.puts("Clients:")
              c.each do |client|
                @stdout.puts("  * #{client.name}")
              end
            end
          end
        else
          @stdout.puts("There are no cucumber-chef test labs to display information for!")
        end

      rescue Exception => e
        $logger.fatal { e.message }
        $logger.fatal { e.backtrace.join("\n") }
        raise TestLabError, e.message
      end

################################################################################

      def lab_exists?
        (labs.size > 0)
      end

################################################################################

      def labs
        results = @connection.servers.select do |server|
          $logger.debug("candidate") { "ID=#{server.id}, state='#{server.state}'" }
          ( server.tags['cucumber-chef-mode'] == Cucumber::Chef::Config[:mode].to_s && VALID_STATES.any?{ |state| state == server.state } )
        end
        results.each do |server|
          $logger.debug("results") { "ID=#{server.id}, state='#{server.state}'" }
        end
        results
      end

################################################################################

      def labs_running
        results = @connection.servers.select do |server|
          $logger.debug("candidate") { "ID=#{server.id}, state='#{server.state}'" }
          ( server.tags['cucumber-chef-mode'] == Cucumber::Chef::Config[:mode].to_s && RUNNING_STATES.any?{ |state| state == server.state } )
        end
        results.each do |server|
          $logger.debug("results") { "ID=#{server.id}, state='#{server.state}'" }
        end
        results
      end

################################################################################

      def labs_shutdown
        results = @connection.servers.select do |server|
          $logger.debug("candidate") { "ID=#{server.id}, state='#{server.state}'" }
          ( server.tags['cucumber-chef-mode'] == Cucumber::Chef::Config[:mode].to_s && SHUTDOWN_STATES.any?{ |state| state == server.state } )
        end
        results.each do |server|
          $logger.debug("results") { "ID=#{server.id}, state='#{server.state}'" }
        end
        results
      end

################################################################################

      def nodes
        Cucumber::Chef.load_knife_config
        query = "tags:#{Cucumber::Chef::Config[:mode]} AND name:cucumber-chef*"
        $logger.debug { "query(#{query})" }
        nodes, offset, total = ::Chef::Search::Query.new.search("node", URI.escape(query))
        nodes.compact
      end

      def clients
        Cucumber::Chef.load_knife_config
        query = "name:cucumber-chef*"
        $logger.debug { "query(#{query})" }
        clients, offset, total = ::Chef::Search::Query.new.search("client", URI.escape(query))
        clients.compact
      end


################################################################################
    private
################################################################################

      def tag_server
        {
          "cucumber-chef-mode" => Cucumber::Chef::Config[:mode],
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
        security_group_name = Cucumber::Chef::Config[:aws][:aws_security_group]
        if (security_group = @connection.security_groups.get(security_group_name))
          port_ranges = security_group.ip_permissions.collect{ |entry| entry["fromPort"]..entry["toPort"] }
          security_group.authorize_port_range(22..22) if port_ranges.none?{ |port_range| port_range === 22 }
          security_group.authorize_port_range(4000..4000) if port_ranges.none?{ |port_range| port_range === 4000 }
          security_group.authorize_port_range(4040..4040) if port_ranges.none?{ |port_range| port_range === 4040 }
        elsif (security_group = @connection.security_groups.new(:name => security_group_name, :description => "cucumber-chef test lab")).save
          security_group.authorize_port_range(22..22)
          security_group.authorize_port_range(4000..4000)
          security_group.authorize_port_range(4040..4040)
        else
          raise TestLabError, "Could not find an existing or create a new AWS security group."
        end
      end

################################################################################

    end

  end
end

################################################################################
