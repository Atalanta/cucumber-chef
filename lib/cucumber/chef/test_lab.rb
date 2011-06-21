module Cucumber
  module Chef
    class TestLabError < Error ; end

    class TestLab
      def initialize(config)
        @config = config
        @connection =
          Fog::Compute.new(:provider => 'AWS',
                           :aws_access_key_id => @config[:knife][:aws_access_key_id],
                           :aws_secret_access_key => @config[:knife][:aws_secret_access_key],
                           :region => @config[:knife][:region])
      end

      def build(output)
        if exists?
          raise TestLabError.new("A test lab already exists using the AWS credentials you supplied")
        end
        server_definition = {
          :image_id => @config[:knife][:aws_image_id],
          :groups => "default",
          :flavor_id => "m1.small",
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
          #server.destroy
          puts server.public_ip_address
        end
        nodes.each do |node|
          # node.destroy
          puts node[:ec2][:public_ipv4]
        end
      end

      def exists?
        running_labs.size > 0
      end

      def info
        "#{node.name}: #{node[:ec2][:public_ipv4]}"
      end

      def public_hostname
        node.cloud.public_hostname
      end

      def node
        @node ||= begin
        search = ::Chef::Search::Query.new
        mode = @config[:mode]
        query = "roles:test_lab_test AND tags:#{mode}"
        nodes, offset, total = search.search("node", URI.escape(query))
        nodes.compact.first
        end
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
    end
  end
end
