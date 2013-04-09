################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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
require 'tempfile'

module Cucumber
  module Chef

    class ContainersError < Error; end

    class Containers

################################################################################

      def initialize(ui=ZTK::UI.new, test_lab=nil)
        @ui, @test_lab = ui, test_lab
      end

################################################################################

      def count
        Container.count
      end

################################################################################

      def create(container)
        # if this is a new or non-persistent container destroy it
        destroy(container.id) if !container.persist

        container.ip ||= self.generate_ip
        container.mac ||= self.generate_mac
        container.persist ||= false
        container.distro ||= "ubuntu"
        container.release ||= "lucid"
        container.arch = detect_arch(container.distro || "ubuntu")

        if running?(container.id)
          @ui.logger.info { "Container '#{container.id}' is already running." }
        else
          @ui.logger.info { "Please wait, creating container #{container.inspect}." }
          bm = ::Benchmark.realtime do
            test_lab_config_dhcpd
            config_network(container)
            _create(container.id, container.distro, container.release, container.arch)
          end
          @ui.logger.info { "Container '#{container.id}' creation took %0.4f seconds." % bm }

          bm = ::Benchmark.realtime do
            ZTK::RescueRetry.try(:tries => 32) do
              @test_lab.ssh.exec("host #{container.id}", :silence => true)
            end
            ZTK::RescueRetry.try(:tries => 32) do
              @test_lab.proxy_ssh(container.id).exec("uptime", :silence => true)
            end
          end
          @ui.logger.info { "Container '#{container.id}' SSHD responded after %0.4f seconds." % bm }
        end
      end

################################################################################

      def destroy(name)
        @test_lab.knife_cli("node delete #{name}", :ignore_exit_status => true)
        @test_lab.knife_cli("client delete #{name}", :ignore_exit_status => true)

        if exists?(name)
          stop(name)
          @test_lab.bootstrap_ssh.exec("sudo lxc-destroy -n #{name}", :silence => true)
          @ui.logger.info { "Destroyed container '#{name}'." }
          test_lab_config_dhcpd
        end
      end

################################################################################

      def provision(container, *args)
        @test_lab.containers.chef_run_client(container, *args)
      end

################################################################################

      def chef_set_client_config(config={})
        @chef_client_config = (@chef_client_config || {
          :log_level => :debug,
          :log_location => "/var/log/chef/client.log",
          :chef_server_url => "https://api.opscode.com/organizations/#{config[:orgname]}",
          :validation_client_name => "#{config[:orgname]}-validator",
          :ssl_verify_mode => :verify_none,
          :environment => nil # use default; i.e. set no value
        }).merge(config)

        @ui.logger.info { "Setting chef client config '#{@chef_client_config.inspect}'." }

        true
      end

################################################################################

      def chef_run_client(container, *args)
        chef_config_client(container)

        @ui.logger.info { "Removing artifacts #{Cucumber::Chef::Config[:artifacts].values.collect{|z| "'#{z}'" }.join(' ')}." }
        (@test_lab.proxy_ssh(container.id).exec("/bin/rm -fv #{Cucumber::Chef::Config[:artifacts].values.join(' ')}", :silence => true) rescue nil)

        @ui.logger.info { "Running chef client on container '#{container.id}'." }

        arguments = {
          "--node-name" => container.id,
          "--json-attributes" => File.join("/etc", "chef", "attributes.json").to_s,
          "--log_level" => @chef_client_config[:log_level],
          "--logfile" => @chef_client_config[:log_location],
          "--server" => @chef_client_config[:chef_server_url],
          "--environment" => (container.chef_client[:environment] || @chef_client_config[:environment])
        }.reject{ |k,v| v.nil? }.sort

        output = nil
        bm = ::Benchmark.realtime do
          output = @test_lab.proxy_ssh(container.id).exec(["/usr/bin/chef-client", arguments, args, "--once"].flatten.join(" "), :silence => true, :ignore_exit_status => true)
        end
        @ui.logger.info { "Chef client run on container '#{container.id}' took %0.4f seconds." % bm }

        chef_client_artifacts(container)

        output
      end

################################################################################

      def enable_minitest(name)
        @chef_client_attributes[:run_list].unshift("recipe[minitest-handler]")
      end

      def run_minitests(name)
        chef_run = chef_run_client(name, "-l info")
        test_result = chef_run.drop_while {|e| e !~ /^# Running tests/}.take_while {|e| e !~ /^[.*] INFO/}
        puts test_result
        test_result
      end

################################################################################
      class << self

        def generate_ip
          octets = [ 192..192,
                     168..168,
                     0..254,
                     1..254 ]
          ip = Array.new
          for x in 1..4 do
            ip << octets[x-1].to_a[rand(octets[x-1].count)].to_s
          end
          ip.join(".")
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

################################################################################

      def list
        @test_lab.bootstrap_ssh.exec("sudo lxc-ls 2>&1", :silence => true).output.strip.split(" ").uniq
      end

################################################################################
    private
################################################################################

      def _create(name, distro, release, arch)
        unless exists?(name)
          cache_rootfs = cache_root(name, distro, release, arch)
          if !File.exists?(cache_rootfs)
            @ui.logger.warn { "'#{name}' has triggered building the lxc file cache for '#{distro}'." }
            @ui.logger.warn { "This one time process per distro can take up to 10 minutes or longer depending on the test lab." }
          end

          @test_lab.bootstrap_ssh.exec(create_command(name, distro, release, arch), :silence => true)

          commands = Array.new

          # install omnibus into the distro/release file cache if it's not already there
          omnibus_chef_client = File.join("/", "opt", "chef", "bin", "chef-client")
          omnibus_cache = File.join(cache_rootfs, omnibus_chef_client)
          @ui.logger.info { "looking for omnibus cache in #{omnibus_cache}" }
          if @test_lab.bootstrap_ssh.exec(%(sudo /bin/bash -c '[[ -f #{omnibus_cache} ]]'), :silence => true, :ignore_exit_status => true).exit_code == 1
            case distro.downcase
            when "ubuntu" then
              @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install wget'), :silence => true)
            when "fedora" then
              @test_lab.bootstrap_ssh.exec(%(sudo yum --nogpgcheck --installroot=#{cache_rootfs} -y install wget openssh-server), :silence => true)
            end
            @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'locale-gen'), :silence => true)
            @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'locale-gen en_US'), :silence => true)
            @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'wget http://www.opscode.com/chef/install.sh'), :silence => true)
            @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'bash install.sh -v #{Cucumber::Chef::Config.chef[:container_version]}'), :silence => true)
            if distro.downcase == "fedora"
              @test_lab.bootstrap_ssh.exec(%(sudo chroot #{cache_rootfs} /bin/bash -c 'rpm -Uvh --nodeps /tmp/*rpm'), :silence => true)
            end
            @test_lab.bootstrap_ssh.exec(%(sudo lxc-destroy -n #{name}), :silence => true)
            @test_lab.bootstrap_ssh.exec(%(sudo #{create_command(name, distro, release, arch)}), :silence => true)
          end

          lab_user_ssh_path = File.join(Cucumber::Chef.lab_user_home_dir, ".ssh")
          lxc_user_ssh_path = File.join(Cucumber::Chef.lxc_user_home_dir, ".ssh")

          lxc_ssh_path = File.join(root(name), Cucumber::Chef.lxc_user_home_dir, ".ssh")
          motd_path = File.join(root(name), "etc", "motd")

          @test_lab.bootstrap_ssh.exec(%(sudo mkdir -vp #{lxc_ssh_path}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(sudo chmod 0700 #{lxc_ssh_path}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(sudo cat #{File.join(lab_user_ssh_path, "id_rsa.pub")} | sudo tee -a #{File.join(lxc_ssh_path, "authorized_keys")}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(sudo cat #{File.join(lxc_user_ssh_path, "id_rsa.pub")} | sudo tee -a #{File.join(lxc_ssh_path, "authorized_keys")}), :silence => true)

          @test_lab.bootstrap_ssh.exec(%(sudo rm -vf #{motd_path}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(sudo cp -v /etc/motd #{motd_path}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(echo "    You are now logged in to the "#{name}" container!\n" | sudo tee -a #{motd_path}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(echo "127.0.0.1 #{name}.#{Cucumber::Chef::Config.test_lab[:tld]} #{name}" | sudo tee -a #{File.join(root(name), "etc", "hosts")}), :silence => true)
          @test_lab.bootstrap_ssh.exec(%(echo "#{name}.test-lab" | sudo tee #{File.join(root(name), "etc", "hostname")}), :silence => true)
        end
        start(name)
      end

################################################################################

      def start(name)
        status = @test_lab.bootstrap_ssh.exec(%(sudo lxc-info -n #{name}), :silence => true).output
        if status.include?("STOPPED")
          @test_lab.bootstrap_ssh.exec(%(sudo lxc-start -d -n #{name}), :silence => true)
        end
      end

      def stop(name)
        status = @test_lab.bootstrap_ssh.exec(%(sudo lxc-info -n #{name}), :silence => true).output
        if status.include?("RUNNING")
          @test_lab.bootstrap_ssh.exec(%(sudo lxc-stop -n #{name}), :silence => true)
        end
      end

################################################################################

      def chef_config_client(container)
        tempfile = Tempfile.new(container.id)
        client_rb = File.join("/", root(container.id), "etc/chef/client.rb")

        @test_lab.bootstrap_ssh.exec(%(sudo mkdir -pv #{File.dirname(client_rb)}), :silence => true)

        if Cucumber::Chef::Config.chef[:render_client_rb]
          max_key_size = @chef_client_config.keys.collect{ |z| z.to_s.size }.max

          File.open(tempfile, 'w') do |f|
            f.puts(Cucumber::Chef.generate_do_not_edit_warning("Chef Client Configuration"))
            f.puts
            @chef_client_config.merge(:node_name => container.id).each do |(key,value)|
              next if value.nil?
              f.puts("%-#{max_key_size}s  %s" % [key, value.inspect])
            end
            f.puts
            f.puts("Mixlib::Log::Formatter.show_time = true")
          end
          @test_lab.bootstrap_ssh.upload(tempfile.path, File.basename(tempfile.path))
          @test_lab.bootstrap_ssh.exec(%(sudo mv -v #{File.basename(tempfile.path)} #{client_rb}), :silence => true)
        else
          @test_lab.bootstrap_ssh.exec(%(sudo /bin/bash -c '[[ -f #{client_rb} ]] && rm -fv #{client_rb}'), :silence => true, :ignore_exit_status => true)
        end

        tempfile = Tempfile.new(container.id)
        attributes_json = File.join("/", root(container.id), "etc", "chef", "attributes.json")
        @test_lab.bootstrap_ssh.exec(%(sudo mkdir -pv #{File.dirname(attributes_json)}), :silence => true)
        File.open(tempfile, 'w') do |f|
          f.puts((container.chef_client || {}).to_json)
        end
        @test_lab.bootstrap_ssh.upload(tempfile.path, File.basename(tempfile.path))
        @test_lab.bootstrap_ssh.exec(%(sudo mv -v #{File.basename(tempfile.path)} #{attributes_json}), :silence => true)

        # make sure our log location is there
        log_location = File.join("/", root(container.id), @chef_client_config[:log_location])
        @test_lab.bootstrap_ssh.exec(%(sudo mkdir -pv #{File.dirname(log_location)}), :silence => true)

        @test_lab.bootstrap_ssh.exec(%(sudo cp /etc/chef/validation.pem #{root(container.id)}/etc/chef/), :silence => true)

        true
      end

################################################################################

      def chef_client_artifacts(container)
        ssh = @test_lab.proxy_ssh(container.id)

        Cucumber::Chef::Config[:artifacts].each do |label, remote_path|
          result = ssh.exec(%(sudo /bin/bash -c '[[ -f #{remote_path} ]] ; echo $? ; true'), :silence => true)
          if (result.output =~ /0/)
            @ui.logger.info { "Retrieving artifact '#{remote_path}' from container '#{container.id}'." }

            local_path = File.join(Cucumber::Chef.artifacts_dir, "#{container.id}-#{File.basename(remote_path)}")
            tmp_path = File.join("/tmp", label)

            FileUtils.mkdir_p(File.dirname(local_path))
            ssh.download(remote_path, tmp_path)
            data = IO.read(tmp_path).chomp

            f = File.open(local_path, "w")
            f.write(data)

            File.chmod(0644, local_path)
          end
        end

        true
      end

################################################################################

      def config_network(container)
        tempfile = Tempfile.new(container.id)
        lxc_network_config = File.join("/etc/lxc", container.id)
        File.open(tempfile, 'w') do |f|
          f.puts(Cucumber::Chef.generate_do_not_edit_warning("LXC Container Configuration"))
          f.puts("")
          f.puts("lxc.network.type = veth")
          f.puts("lxc.network.flags = up")
          f.puts("lxc.network.link = br0")
          f.puts("lxc.network.name = eth0")
          f.puts("lxc.network.hwaddr = #{container.mac}")
          f.puts("lxc.network.ipv4 = 0.0.0.0")
        end
        @test_lab.bootstrap_ssh.upload(tempfile.path, File.basename(tempfile.path))
        @test_lab.bootstrap_ssh.exec(%(sudo mv -v #{File.basename(tempfile.path)} #{lxc_network_config}), :silence => true)
      end

################################################################################

      def test_lab_config_dhcpd
        tempfile = Tempfile.new("dhcpd")
        dhcpd_config = File.join("/etc/dhcp/test-lab.conf")
        File.open(tempfile, 'w') do |f|
          f.puts(Cucumber::Chef.generate_do_not_edit_warning("DHCPD Configuration"))
          Container.all.each do |container|
            next if [container.mac, container.ip].any?{ |z| z.nil? }

            f.puts
            f.puts("host #{container.id} {")
            f.puts("  hardware ethernet #{container.mac};")
            f.puts("  fixed-address #{container.ip};")
            f.puts("  ddns-hostname \"#{container.id}\";")
            f.puts("}")
          end
          f.flush
          f.close
        end
        @test_lab.bootstrap_ssh.upload(tempfile.path, File.basename(tempfile.path))
        @test_lab.bootstrap_ssh.exec(%(sudo mv -v #{File.basename(tempfile.path)} #{dhcpd_config}), :silence => true)

        @test_lab.bootstrap_ssh.exec("sudo service isc-dhcp-server restart", :silence => true)
        @test_lab.bootstrap_ssh.exec("sudo service bind9 restart", :silence => true)
      end

################################################################################

      def detect_arch(distro)
        @arch ||= @test_lab.bootstrap_ssh.exec("uname -m", :silence => true).output.chomp
        case distro.downcase
        when "ubuntu" then
          ((@arch =~ /x86_64/) ? "amd64" : "i386")
        when "fedora" then
          ((@arch =~ /x86_64/) ? "amd64" : "i686")
        end
      end

################################################################################

      def running?(name)
        status = @test_lab.bootstrap_ssh.exec(%(sudo lxc-info -n #{name}), :silence => true).output.chomp
        status.include?("RUNNING")
      end

################################################################################

      def exists?(name)
        (@test_lab.bootstrap_ssh.exec(%(sudo /bin/bash -c '[[ -d #{root(name)} ]] ; echo $? ; true'), :silence => true).output.chomp =~ /0/)
      end

################################################################################

      def root(name)
        File.join("/", "var", "lib", "lxc", name, "rootfs")
      end

################################################################################

      def cache_root(name, distro, release, arch)
        case distro.downcase
        when "ubuntu" then
          cache_root = File.join("/", "var", "cache", "lxc", release, "rootfs-#{arch}")
        when "fedora" then
          cache_root = File.join("/", "var", "cache", "lxc", distro, arch, release, "rootfs")
        end
      end

################################################################################

      def create_command(name, distro, release, arch)
        case distro.downcase
        when "ubuntu" then
          %(sudo DEBIAN_FRONTEND=noninteractive lxc-create -n #{name} -f /etc/lxc/#{name} -t #{distro} -- --release #{release} --arch #{arch})
        when "fedora" then
          %(sudo lxc-create -n #{name} -f /etc/lxc/#{name} -t #{distro} -- --release #{release})
        end
      end

################################################################################

    end

  end
end

################################################################################
