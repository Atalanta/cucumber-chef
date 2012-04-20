module Cucumber
  module Chef
    class TestLabError < Error ; end

    class TestLab
      attr_reader :connection, :server

      INVALID_STATES = ['terminated', 'shutting-down', 'starting-up', 'pending']
      RUNNING_STATES = ['running']
      SHUTDOWN_STATES = ['shutdown', 'stopping', 'stopped']
      VALID_STATES = RUNNING_STATES+SHUTDOWN_STATES

      def initialize(config)
        @config = config
        @connection = Fog::Compute.new(:provider => 'AWS',
                                       :aws_access_key_id => @config[:knife][:aws_access_key_id],
                                       :aws_secret_access_key => @config[:knife][:aws_secret_access_key],
                                       :region => @config[:knife][:region])
        ensure_security_group if @config.security_group == "cucumber-chef"
      end

################################################################################

      def create
        if labs_exists?
          puts("A test lab already exists using the AWS credentials you have supplied; attempting to reprovision it.")
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
          puts "Provisioning cucumber-chef test lab platform."
          print("Waiting for instance...")
          @server.wait_for { print "."; ready? }
          puts("OK.\n")
          tag_server
        end

        info

        print("Waiting for sshd...")
        print(".") until sshd_ready?(@server.public_ip_address)
        puts("OK.\n")

        @server
      end


      def destroy
        labs_running.each do |server|
          puts "Destroying Server: #{server.public_ip_address}"
          server.destroy
        end
        nodes.each do |node|
          puts "Destroying Node: #{node[:cloud][:public_ipv4]}"
          node.destroy
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
        if labs_exists?
          labs.each do |lab|
            puts("----------------------------------------------------------------------------")
            puts("Instance ID: #{lab.id}")
            puts("State: #{lab.state}")
            puts("Username: #{lab.username}") if lab.username
            puts("IP Address:")
            puts("  Public...: #{lab.public_ip_address}") if lab.public_ip_address
            puts("  Private..: #{lab.private_ip_address}") if lab.private_ip_address
            puts("DNS:")
            puts("  Public...: #{lab.dns_name}") if lab.dns_name
            puts("  Private..: #{lab.private_dns_name}") if lab.private_dns_name
            puts("Tags:")
            lab.tags.to_hash.each do |k,v|
              puts("  #{k}: #{v}")
            end
          end
          puts("----------------------------------------------------------------------------")
        else
          puts("There are no test labs to display information for!")
        end
      end

      def labs_exists?
        (labs.size > 0)
      end

      def labs
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode] && VALID_STATES.any?{|state| s.state == state}) }
      end

      def labs_running
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode] && RUNNING_STATES.any?{|state| s.state == state}) }
      end

      def labs_shutdown
        @connection.servers.select{ |s| (s.tags['cucumber-chef'] == @config[:mode] && SHUTDOWN_STATES.any?{|state| s.state == state}) }
      end

################################################################################

#      def public_hostname
#        puts "NODES:"
#        puts y nodes
#        nodes.first.cloud.public_hostname
#      end

      def nodes
        search = ::Chef::Search::Query.new
        mode = @config[:mode]
        query = "roles:test_lab AND tags:#{mode}"
        nodes, offset, total = search.search("node", URI.escape(query))
        nodes.compact
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

      def sshd_ready?(address)
        sleep 1
        socket = TCPSocket.new(address, 22)
        ((IO.select([socket], nil, nil, 5) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::ECONNREFUSED
        false
      ensure
        (socket && socket.close)
      end

    end
  end
end
