module Cucumber
  module Chef
    module Handy

################################################################################

      def get_root(name)
        File.join('/var/lib/lxc', name, 'rootfs')
      end

      def create_network_config(name)
        network_config = File.join("/etc/lxc", name)
        File.open(network_config, 'w') do |f|
          f.puts "lxc.network.type = veth"
          f.puts "lxc.network.flags = up"
          f.puts "lxc.network.link = br0"
          f.puts "lxc.network.name = eth0"
          f.puts "lxc.network.hwaddr = #{@servers[name][:mac]}"
          f.puts "lxc.network.ipv4 = 0.0.0.0"
        end
      end

      def create_dhcp_config
        File.open("/etc/dhcp3/lxc.conf", 'w') do |f|
          f.puts "option subnet-mask 255.255.0.0;"
          f.puts "option broadcast-address 192.168.255.255;"
          f.puts "option routers 192.168.255.254;"
          f.puts "option domain-name \"cucumber-chef.org\";"
          f.puts "option domain-name-servers 8.8.8.8, 8.8.4.4;"
          f.puts ""
          f.puts "subnet 192.168.0.0 netmask 255.255.0.0 {"
          f.puts "  range 192.168.255.1 192.168.255.100;"
          f.puts "}"
          @servers.each do |key, value|
            f.puts ""
            f.puts "host #{key} {"
            f.puts "  hardware ethernet #{value[:mac]};"
            f.puts "  fixed-address #{value[:ip]};"
            f.puts "}"
          end
        end
        %x(service dhcp3-server restart)
      end

      def generate_mac
        digits = [ %w(0),
                   %w(0),
                   %w(0),
                   %w(0),
                   %w(5),
                   %w(e),
                   %w(0 1 2 3 4 5 6 7 8 9 a b c d e f),
                   %w(0 1 2 3 4 5 6 7 8 9 a b c d e f),
                   %w(5 6 7 8 9 a b c d e f),
                   %w(3 4 5 6 7 8 9 a b c d e f),
                   %w(0 1 2 3 4 5 6 7 8 9 a b c d e f),
                   %w(0 1 2 3 4 5 6 7 8 9 a b c d e f) ]
        mac = ""
        for x in 1..12 do
          mac += digits[x-1][rand(digits[x-1].count)]
          mac += ":" if (x.modulo(2) == 0) && (x != 12)
        end
        mac
      end

################################################################################

      def run_chroot(name, command)
        %x(chroot #{get_root(name)} /bin/bash -c '#{command}' 2>&1)
      end

      def run_remote_command(name, command)
        %x(ssh #{@server[name]} '#{command}')
      end

################################################################################

      def create_server(server, ip)
        @servers[server] = { :ip => ip, :mac => generate_mac }
        create_network_config(server)
        create_dhcp_config
        create_container(server)
      end

      def destroy_server(server)
        destroy_container(server)
      end

      def list_servers
        list_containers
      end

################################################################################

      def create_container(name)
        unless File.exists?(get_root(name))
          %x(lxc-create -n #{name} -f /etc/lxc/#{name} -t ubuntu 2>&1)
        end
        start_container(name)
      end

      def destroy_container(name)
        stop_container(name)
        if File.exists?(get_root(name))
          %x(lxc-destroy -n #{name} 2>&1)
        end
      end

      def start_container(name)
        status = %x(lxc-info -n #{name} 2>&1)
        if status.include?("STOPPED")
          %x(lxc-start -d -n #{name})
          sleep 5
        end
      end

      def stop_container(name)
        status = %x(lxc-info -n #{name} 2>&1)
        if status.include?("RUNNING")
          %x(lxc-stop -n #{name})
          sleep 5
        end
      end

      def list_containers
        %x(lxc-ls 2>&1).split("\n").uniq
      end

################################################################################

      def set_run_list(name, run_list)
        rl = Hash.new
        a = Array.new
        a << run_list
        rl['run_list'] = a
        first_boot = File.join(get_root(name), "/etc/chef/first-boot.json")
        File.open(first_boot, 'w') do |f|
          f.puts rl.to_json
        end
      end

      def run_chef(name)
        run_chroot(name, "/usr/bin/chef-client -j /etc/chef/first-boot.json -N cucumber-chef-#{name}")
      end

      def databag_item_from_file(file)
        ::Chef::JSONCompat.from_json(File.read(file))
      end

      def upload_databag_item(databag, item)
        ::Chef::Config.from_file("/etc/chef/client.rb")
        databag_item = ::Chef::DataBagItem.new
        databag_item.data_bag(databag)
        databag_item.raw_data = item
        databag_item.save
      end

      def create_client_rb(orgname)
        client_rb = File.join(get_root(name), "etc/chef/client.rb")
        File.open(client_rb, 'w') do |f|
          f.puts "log_level               :debug"
          f.puts "log_location            \"/var/log/chef.log\""
          f.puts "chef_server_url         \"https://api.opscode.com/organizations/#{orgname}\""
          f.puts "validation_client_name  \"#{orgname}-validator\""
          f.puts "node_name               \"cucumber-chef-#{name}\""
        end
      end

    end
  end
end
