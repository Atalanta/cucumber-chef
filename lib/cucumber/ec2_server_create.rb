require 'fog'
require 'socket'
require 'chef/knife'
require 'chef/knife/bootstrap'
require 'chef/json_compat'

class Chef
  class Knife
    class Ec2ServerCreate < Knife

      attr_accessor :initial_sleep_delay

      def tcp_test_ssh(hostname)
        tcp_socket = TCPSocket.new(hostname, 22)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

      def run
        require 'fog'
        require 'highline'
        require 'net/ssh/multi'
        require 'readline'

        $stdout.sync = true

        connection = Fog::Compute.new(
                                      :provider => 'AWS',
                                      :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
                                      :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
                                      :region => #REGION
                                      )

        # WHAT IS THIS FOR?
        ami = connection.images.get(locate_config_value(:image))

        server_def = {
        :image_id => locate_config_value(:image),
        :groups => config[:security_groups],
        :flavor_id => locate_config_value(:flavor),
        :key_name => Chef::Config[:knife][:aws_ssh_key_id],
        :availability_zone => Chef::Config[:knife][:availability_zone]
      }

      server = connection.servers.create(server_def)

      puts "Instance ID: #{server.id}"
      print "\n#{h.color("Waiting for server", :magenta)}"

      # wait for it to be ready to do stuff
      server.wait_for { print "."; ready? }

      puts("\n")

      puts "Public IP Address #{server.public_ip_address}"
      
      print "\n#{h.color("Waiting for sshd", :magenta)}"

      print(".") until tcp_test_ssh(server.dns_name) { sleep @initial_sleep_delay ||= 10; puts("done") }

      bootstrap_for_node(server).run

    end

    def bootstrap_for_node(server)
      bootstrap = Chef::Knife::Bootstrap.new
      bootstrap.name_args = [server.dns_name]
      bootstrap.config[:run_list] = config[:run_list]
      bootstrap.config[:ssh_user] = config[:ssh_user]
      bootstrap.config[:identity_file] = config[:identity_file]
      bootstrap.config[:chef_node_name] = config[:chef_node_name] || server.id
      bootstrap.config[:prerelease] = config[:prerelease]
      bootstrap.config[:distro] = locate_config_value(:distro)
      bootstrap.config[:use_sudo] = true
      bootstrap.config[:template_file] = locate_config_value(:template_file)
      bootstrap.config[:environment] = config[:environment]
      bootstrap
    end

    def locate_config_value(key)
      key = key.to_sym
      Chef::Config[:knife][key] || config[key]
    end
  end
end
end
