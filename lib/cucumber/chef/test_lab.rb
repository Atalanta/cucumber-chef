module Cucumber
  module Chef
    class TestLabError < Error ; end

    class TestLab
      attr_reader :connection

      def initialize(config)
        @config = config
        @connection =
          Fog::Compute.new(:provider => 'AWS',
                           :aws_access_key_id => @config[:knife][:aws_access_key_id],
                           :aws_secret_access_key => @config[:knife][:aws_secret_access_key],
                           :region => @config[:knife][:region])
        ensure_security_group if @config.security_group == "cucumber-chef"
      end

      def build(output)
        if exists?
          raise TestLabError.new("A test lab already exists using the AWS credentials you supplied")
        end
        server_definition = {
          :image_id => @config.aws_image_id,
          :groups => @config.security_group,
          :flavor_id => @config.aws_instance_type,
          :key_name => @config[:knife][:aws_ssh_key_id],
          :availability_zone => @config[:knife][:availability_zone],
          :tags => {"purpose" => "cucumber-chef"},
          :identity_file => @config[:knife][:identity_file]
        }
        @server = @connection.servers.create(server_definition)
        output.puts "Provisioning cucumber-chef test lab platform."
        output.print "Waiting for server"
        @server.wait_for { output.print "."; ready? }
        output.puts("\n")
        tag_server
        output.puts "Instance ID: #{@server.id} ; IP Address #{@server.public_ip_address}"
        output.puts "Platform provisioned.  Run cucumber-chef project to get started."
        @server
      end

      def destroy
        running_labs.each do |server|
          puts "Destroying Server: #{server.public_ip_address}"
          server.destroy
        end
        nodes.each do |node|
          puts "Destroying Node: #{node[:cloud][:public_ipv4]}"
          node.destroy
        end
      end

      def exists?
        running_labs.size > 0
      end

      def info
        (exists? && running_labs.first.public_ip_address) || ""
      end

      def public_hostname
        nodes.first.cloud.public_hostname
      end

      def nodes
        search = ::Chef::Search::Query.new
        mode = @config[:mode]
        query = "roles:test_lab_test AND tags:#{mode}"
        nodes, offset, total = search.search("node", URI.escape(query))
        nodes.compact
      end

      def running_labs
        @connection.servers.select do |s|
          s.tags['cucumber-chef'] == @config[:mode] && s.state == 'running'
        end
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
