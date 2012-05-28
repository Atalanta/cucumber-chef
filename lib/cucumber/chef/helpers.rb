module Cucumber
  module Chef
    module Helpers

################################################################################

      def run_chroot_command(name, command)
        %x(chroot #{get_root(name)} /bin/bash -c '#{command}' 2>&1)
      end

      def run_remote_command(name, command)
        %x(ssh #{@servers[name][:ip]} '#{command}' 2>&1)
      end

################################################################################

      def log(name, ip, message)
        STDOUT.puts("\033[34m  * #{ip}: (LXC) '#{name}' #{message}\033[0m")
      end

      def create_server(name, ip=nil, mac=nil)
        ip = (ip || generate_ip)
        mac = (mac || generate_mac)
        @servers = (@servers || {}).merge(name => { :ip => ip, :mac => mac })

        log(name, ip, "Building")

        create_dhcp_config
        create_network_config(name)
        create_container(name)
        %x(mkdir -p #{get_root(name)}/root/.ssh/ 2>&1)
        %x(chmod 0700 #{get_root(name)}/root/.ssh/ 2>&1)
        %x(cat /root/.ssh/id_rsa.pub > #{get_root(name)}/root/.ssh/authorized_keys 2>&1)
        sleep(1) until container_sshd_ready?(ip)

        log(name, ip, "Booted")

        run_remote_command(name, "DEBIAN_FRONTEND=noninteractive apt-get -q -y --force-yes install curl 2>&1")
        run_remote_command(name, "curl -L http://www.opscode.com/chef/install.sh | bash 2>&1")
        create_client_rb(name)
        %x(cp /etc/chef/validation.pem #{get_root(name)}/etc/chef/ 2>&1)

        log(name, ip, "Ready")
      end

      def destroy_server(name)
        destroy_container(name)
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
        end
      end

      def stop_container(name)
        status = %x(lxc-info -n #{name} 2>&1)
        if status.include?("RUNNING")
          %x(lxc-stop -n #{name})
        end
      end

      def list_containers
        %x(lxc-ls 2>&1).split("\n").uniq
      end

################################################################################

      # call this in a Before hook
      def set_chef_client(attributes={})
        @chef_client = { :log_level => :debug,
                         :log_location => "/var/log/chef.log",
                         :chef_server_url => "https://api.opscode.com/organizations/#{attributes[:orgname]}",
                         :validation_client_name => "#{attributes[:orgname]}-validator" }.merge(attributes)
      end

      # call this before run_chef
      def set_chef_client_attributes(name, attributes={})
        attributes_json = Pathname.new(File.join("/", get_root(name), "etc", "chef", "attributes.json"))
        FileUtils.mkdir_p(File.dirname(attributes_json))
        File.open(attributes_json, 'w') do |f|
          f.puts(attributes.to_json)
        end
      end

      def run_chef(name)
        run_remote_command(name, "/usr/bin/chef-client -j /etc/chef/attributes.json -N cucumber-chef-#{name}")
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

      def create_client_rb(name)
        client_rb = Pathname.new(File.join("/", get_root(name), "etc", "chef", "client.rb"))
        FileUtils.mkdir_p(File.dirname(client_rb))
        File.open(client_rb, 'w') do |f|
          f.puts("log_level               :#{@chef_client[:log_level]}")
          f.puts("log_location            \"#{@chef_client[:log_location]}\"")
          f.puts("chef_server_url         \"#{@chef_client[:chef_server_url]}\"")
          f.puts("validation_client_name  \"#{@chef_client[:validation_client_name]}\"")
          f.puts("node_name               \"cucumber-chef-#{name}\"")
        end
      end

################################################################################

      def get_root(name)
        Pathname.new(File.join("/", "var", "lib", "lxc", name, "rootfs"))
      end

      def create_network_config(name)
        lxc_network_config = Pathname.new(File.join("/", "etc", "lxc", name))
        File.open(lxc_network_config, 'w') do |f|
          f.puts("lxc.network.type = veth")
          f.puts("lxc.network.flags = up")
          f.puts("lxc.network.link = br0")
          f.puts("lxc.network.name = eth0")
          f.puts("lxc.network.hwaddr = #{@servers[name][:mac]}")
          f.puts("lxc.network.ipv4 = 0.0.0.0")
        end
      end

      def create_dhcp_config
        dhcpd_lxc_config = Pathname.new(File.join("/", "etc", "dhcp3", "lxc.conf"))
        File.open(dhcpd_lxc_config, 'w') do |f|
          f.puts("option subnet-mask 255.255.0.0;")
          f.puts("option broadcast-address 192.168.255.255;")
          f.puts("option routers 192.168.255.254;")
          f.puts("option domain-name \"cucumber-chef.org\";")
          f.puts("option domain-name-servers 8.8.8.8, 8.8.4.4;")
          f.puts("")
          f.puts("subnet 192.168.0.0 netmask 255.255.0.0 {")
          f.puts("  range 192.168.255.1 192.168.255.100;")
          f.puts("}")
          @servers.each do |key, value|
            f.puts("")
            f.puts("host #{key} {")
            f.puts("  hardware ethernet #{value[:mac]};")
            f.puts("  fixed-address #{value[:ip]};")
            f.puts("}")
          end
        end
        %x(service dhcp3-server restart)
      end

      def container_sshd_ready?(ip)
        sleep 1
        socket = TCPSocket.new(ip, 22)
        ((IO.select([socket], nil, nil, 5) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      ensure
        (socket && socket.close)
      end

      def generate_ip
        octets = [ 192..192,
                   168..168,
                   0..254,
                   1..254 ]
        ip = ""
        for x in 1..4 do
          ip += octets[x-1].to_a[rand(octets[x-1].count)].to_s
          ip += "." if x != 4
        end
        ip
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

    end
  end
end
