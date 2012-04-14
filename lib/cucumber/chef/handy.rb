module Cucumber
  module Chef
    module Handy
      def get_root(name)
        File.join('/var/lib/lxc', name, 'rootfs')
      end

      def create_server(server, ip)
        create_network_config(server, ip)
        create_container(server)
      end

      def create_network_config(name, ip)
        network_config = File.join("/etc/lxc", name)
        File.open(network_config, 'w') do |f|
          f.puts "lxc.network.type = veth"
          f.puts "lxc.network.flags = up"
          f.puts "lxc.network.link = br0"
          f.puts "lxc.network.name = eth0"
          f.puts "lxc.network.ipv4 = #{ip}/24"
        end
      end

      def create_container(name)
        unless File.exists?(get_root(name))
          %x[lxc-create -n #{name} -f /etc/lxc/#{name} -t lucid-chef > /dev/null 2>&1 ]
        end
      end

      def set_run_list(name, run_list)
        rl = Hash.new
        a = Array.new
        a << run_list
        rl['run_list'] = a
        first_boot = File.join(get_root(name), '/etc/chef/first-boot.json')
        File.open(first_boot, 'w') do |f|
          f.puts rl.to_json
        end
      end

      def run_chef_first_time(name)
        %x[chroot #{get_root(name)} /bin/bash -c 'chef-client -j /etc/chef/first-boot.json -N #{name} > /dev/null 2>&1']
      end

      def run_chef(name)
        %x[chroot #{get_root(name)} /bin/bash -c 'chef-client > /dev/null 2>&1']
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
        client_rb = File.join(get_root(name), 'etc/chef/client.rb')
        File.open(client_rb, 'w') do |f|
          f.puts "log_level        :info"
          f.puts "log_location     STDOUT"
          f.puts "chef_server_url  'https://api.opscode.com/organizations/#{orgname}'"
          f.puts "validation_client_name '#{orgname}-validator'"
          f.puts "node_name 'cucumber-chef-#{name}'"
        end
      end

      def start_container(name)
        status = %x[lxc-info -n #{name} 2>&1]
        if status.include?("STOPPED")
          %x[lxc-start -d -n #{name}]
          sleep 5
        end
      end

      def stop_container(name)
        status = %x[lxc-info -n #{name} 2>&1]
        if status.include?("RUNNING")
          %x[lxc-stop -n #{name}]
          sleep 5
        end
      end

      def run_remote_command(remote_server, command)
        %x[ssh workstation.testlab 'ssh #{remote_server} #{command}']
      end
    end
  end
end
