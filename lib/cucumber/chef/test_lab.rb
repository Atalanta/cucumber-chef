module Cucumber
  module Chef

    class TestLabError < Error; end

    class TestLab
      attr_reader :connection, :server
      attr_accessor :stdout, :stderr, :stdin

      INVALID_STATES = ['terminated', 'shutting-down', 'starting-up', 'pending']
      RUNNING_STATES = ['running']
      SHUTDOWN_STATES = ['shutdown', 'stopping', 'stopped']
      VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

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
        if labs_exist?
          @stdout.puts("A test lab already exists using the AWS credentials you have supplied; attempting to reprovision it.")
          @server = labs_running.first
        else
          server_definition = {
            :image_id => Cucumber::Chef::Config.aws_image_id,
            :groups => Cucumber::Chef::Config[:aws][:security_group],
            :flavor_id => Cucumber::Chef::Config[:aws][:aws_instance_type],
            :key_name => Cucumber::Chef::Config[:aws][:aws_ssh_key_id],
            :availability_zone => Cucumber::Chef::Config[:aws][:availability_zone],
            :tags => { "purpose" => "cucumber-chef", "cucumber-chef" => Cucumber::Chef::Config[:mode] },
            :identity_file => Cucumber::Chef::Config[:aws][:identity_file]
          }
          @server = @connection.servers.create(server_definition)
          @stdout.puts("Provisioning cucumber-chef test lab platform.")

          @stdout.print("Waiting for instance...")
          @server.wait_for { ready? }
          @stdout.puts("OK!\n")

          tag_server
        end

        info

        @stdout.print("Waiting for sshd...")
        begin
          @stdout.print(".")
          sleep(1)
        end until Cucumber::Chef::SSH.ready?(@server.public_ip_address)
        @stdout.puts("OK!\n")

        @stdout.puts("Instance provisioned!")

        @server
      end


      def destroy
        l = labs
        n = nodes
        c = clients

        if (l.count > 0)
          @stdout.puts("Destroying Servers:")
          l.each do |server|
            @stdout.puts("  * #{server.public_ip_address}")
            server.destroy
          end
        end

#        if (n.count > 0)
#          @stdout.puts("Destroying Chef Nodes:")
#          n.each do |node|
#            @stdout.puts("  * #{node.name}")
#            node.destroy
#          end
#        end

#        if (c.count > 0)
#          @stdout.puts("Destroying Chef Clients:")
#          c.each do |client|
#            @stdout.puts("  * #{client.name}")
#            client.destroy
#          end
#        end
      end

################################################################################

      def start
        # TODO: Implementation
      end


      def stop
        # TODO: Implementation
      end

################################################################################

      def info
        @stdout.puts("----------------------------------------------------------------------------")
        if labs_exist?
          labs.each do |lab|
            @stdout.puts("Instance ID: #{lab.id}")
            @stdout.puts("State: #{lab.state}")
            @stdout.puts("Username: #{lab.username}") if lab.username
            @stdout.puts("IP Address:")
            @stdout.puts("  Public...: #{lab.public_ip_address}") if lab.public_ip_address
            @stdout.puts("  Private..: #{lab.private_ip_address}") if lab.private_ip_address
            @stdout.puts("DNS:")
            @stdout.puts("  Public...: #{lab.dns_name}") if lab.dns_name
            @stdout.puts("  Private..: #{lab.private_dns_name}") if lab.private_dns_name
            @stdout.puts("Tags:")
            lab.tags.to_hash.each do |k,v|
              @stdout.puts("  #{k}: #{v}")
            end
          end
        else
          @stdout.puts("There are no test labs to display information for!")
        end
        @stdout.puts("----------------------------------------------------------------------------")
        if ((n = nodes).count > 0)
          @stdout.puts("Chef Nodes:")
          n.each do |node|
            @stdout.puts("  * #{node}")
          end
        else
          @stdout.puts("There are no chef nodes to display information for!")
        end
        @stdout.puts("----------------------------------------------------------------------------")
        if ((c = clients).count > 0)
          @stdout.puts("Chef Clients:")
          c.each do |client|
            @stdout.puts("  * #{client}")
          end
        else
          @stdout.puts("There are no chef clients to display information for!")
        end
        @stdout.puts("----------------------------------------------------------------------------")
      end

      def labs_exist?
        (labs.size > 0)
      end

      def labs
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == Cucumber::Chef::Config[:mode].to_s && VALID_STATES.any?{|state| s.state == state}) }
      end

      def labs_running
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == Cucumber::Chef::Config[:mode].to_s && RUNNING_STATES.any?{|state| s.state == state}) }
      end

      def labs_shutdown
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == Cucumber::Chef::Config[:mode].to_s && SHUTDOWN_STATES.any?{|state| s.state == state}) }
      end

################################################################################

      def nodes
        mode = Cucumber::Chef::Config[:mode]
        command = Cucumber::Chef::Command.new(StringIO.new, StringIO.new, StringIO.new)
        output = command.knife("search node \"tags:#{mode} AND name:cucumber-chef*\"", "-a name", "-F json")
        JSON.parse(output)["rows"].collect{ |row| row["name"] }
      end

      def clients
        mode = Cucumber::Chef::Config[:mode]
        command = Cucumber::Chef::Command.new(StringIO.new, StringIO.new, StringIO.new)
        output = command.knife("search node \"name:cucumber-chef*\"", "-a name", "-F json")
        JSON.parse(output)["rows"].collect{ |row| row["name"] }
      end


    private

      def tag_server
        tag = @connection.tags.new
        tag.resource_id = @server.id
        tag.key = "cucumber-chef"
        tag.value = Cucumber::Chef::Config[:mode]
        tag.save
      end

      def ensure_security_group
        security_group = Cucumber::Chef::Config[:aws][:security_group]
        unless @connection.security_groups.get(security_group)
          @connection.create_security_group(security_group, 'cucumber-chef test lab')
          @connection.security_groups.get(security_group).authorize_port_range(22..22)
          @connection.security_groups.get(security_group).authorize_port_range(4000..4000)
          @connection.security_groups.get(security_group).authorize_port_range(4040..4040)
        end
      end

    end

  end
end
