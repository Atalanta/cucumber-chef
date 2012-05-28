module Cucumber
  module Chef
    class TestLabError < Error ; end

    class TestLab
      attr_reader :connection, :server
      attr_accessor :stdout, :stderr, :stdin

      INVALID_STATES = ['terminated', 'shutting-down', 'starting-up', 'pending']
      RUNNING_STATES = ['running']
      SHUTDOWN_STATES = ['shutdown', 'stopping', 'stopped']
      VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

      def initialize(config, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @config = config
        @connection = Fog::Compute.new(:provider => 'AWS',
                                       :aws_access_key_id => @config[:knife][:aws_access_key_id],
                                       :aws_secret_access_key => @config[:knife][:aws_secret_access_key],
                                       :region => @config[:knife][:region])
        ensure_security_group if @config.security_group == "cucumber-chef"
      end

################################################################################

      def create
        if labs_exist?
          @stdout.puts("A test lab already exists using the AWS credentials you have supplied; attempting to reprovision it.")
          @server = labs_running.first
        else
          server_definition = {
            :image_id => @config.aws_image_id,
            :groups => @config.security_group,
            :flavor_id => @config.aws_instance_type,
            :key_name => @config[:knife][:aws_ssh_key_id],
            :availability_zone => @config[:knife][:availability_zone],
            :tags => {"purpose" => "cucumber-chef", "cucumber-chef" => @config[:mode]},
            :identity_file => @config[:knife][:identity_file]
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

        if (n.count > 0)
          @stdout.puts("Destroying Chef Nodes:")
          n.each do |node|
            @stdout.puts("  * #{node.name}")
            node.destroy
          end
        end

        if (c.count > 0)
          @stdout.puts("Destroying Chef Clients:")
          c.each do |client|
            @stdout.puts("  * #{client.name}")
            client.destroy
          end
        end
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
            @stdout.puts("  * #{node.name}")
          end
        else
          @stdout.puts("There are no chef nodes to display information for!")
        end
        @stdout.puts("----------------------------------------------------------------------------")
        if ((c = clients).count > 0)
          @stdout.puts("Chef Clients:")
          c.each do |client|
            @stdout.puts("  * #{client.name}")
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
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode].to_s && VALID_STATES.any?{|state| s.state == state}) }
      end

      def labs_running
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode].to_s && RUNNING_STATES.any?{|state| s.state == state}) }
      end

      def labs_shutdown
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode].to_s && SHUTDOWN_STATES.any?{|state| s.state == state}) }
      end

################################################################################

      def nodes
        mode = @config[:mode]
        nodes, offset, total = ::Chef::Search::Query.new.search(:node, "tags:#{mode} AND name:cucumber-chef*")
        nodes.compact
      end

      def clients
        n = nodes
        mode = @config[:mode]
        clients, offset, total = ::Chef::Search::Query.new.search(:client)
        clients.compact.reject{ |client| !n.map(&:name).include?(client.name) }
      end


    private

      def tag_server
        tag = @connection.tags.new
        tag.resource_id = @server.id
        tag.key = "cucumber-chef"
        tag.value = @config[:mode]
        tag.save
      end

      def ensure_security_group
        unless @connection.security_groups.get(@config.security_group)
          @connection.create_security_group(@config.security_group, 'cucumber-chef test lab')
          @connection.security_groups.get(@config.security_group).authorize_port_range(22..22)
        end
      end

    end
  end
end
