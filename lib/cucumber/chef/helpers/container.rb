################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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

module Cucumber::Chef::Helpers::Container

################################################################################

  def container_create(name, distro, release, arch)
    unless container_exists?(name)
      cache_rootfs = container_cache_root(name, distro, release, arch)
      if !File.exists?(cache_rootfs)
        log("$#{name}$ has triggered building the lxc file cache for $#{distro}$")
        log("this one time process per distro can take up to 10 minutes or longer depending on the test lab hardware")
      end

      command_run_local(container_create_command(name, distro, release, arch))

      # install omnibus into the distro/release file cache if it's not already there
      omnibus_chef_client = File.join("/", "opt", "chef", "bin", "chef-client")
      omnibus_cache = File.join(cache_rootfs, omnibus_chef_client)
      logger.info { "looking for omnibus cache in #{omnibus_cache}" }
      if !File.exists?(omnibus_cache)
        case distro.downcase
        when "ubuntu" then
          command_run_local("chroot #{cache_rootfs} /bin/bash -c 'apt-get -y --force-yes install wget'")
        when "fedora" then
          command_run_local("yum --nogpgcheck --installroot=#{cache_rootfs} -y install wget openssh-server")
        end
        command_run_local("chroot #{cache_rootfs} /bin/bash -c 'wget http://www.opscode.com/chef/install.sh -O - | bash'")
        if distro.downcase == "fedora"
          command_run_local("chroot #{cache_rootfs} /bin/bash -c 'rpm -Uvh --nodeps /tmp/*rpm'")
        end
        command_run_local("lxc-destroy -n #{name}")
        command_run_local(container_create_command(name, distro, release, arch))
      end

      command_run_local("mkdir -p #{container_root(name)}/root/.ssh")
      command_run_local("chmod 0755 #{container_root(name)}/root/.ssh")
      command_run_local("cat /root/.ssh/id_rsa.pub | tee -a #{container_root(name)}/root/.ssh/authorized_keys")
      command_run_local("cat /home/#{Cucumber::Chef::Config[:lab_user]}/.ssh/id_rsa.pub | tee -a #{container_root(name)}/root/.ssh/authorized_keys")

      command_run_local("mkdir -p #{container_root(name)}/home/#{Cucumber::Chef::Config[:lab_user]}/.ssh")
      command_run_local("chmod 0755 #{container_root(name)}/home/#{Cucumber::Chef::Config[:lab_user]}/.ssh")
      command_run_local("cat /root/.ssh/id_rsa.pub | tee -a #{container_root(name)}/home/#{Cucumber::Chef::Config[:lab_user]}/.ssh/authorized_keys")
      command_run_local("cat /home/#{Cucumber::Chef::Config[:lab_user]}/.ssh/id_rsa.pub | tee -a #{container_root(name)}/home/#{Cucumber::Chef::Config[:lab_user]}/.ssh/authorized_keys")
      command_run_local("chown -R #{Cucumber::Chef::Config[:lab_user]}:#{Cucumber::Chef::Config[:lab_user]} #{container_root(name)}/home/#{Cucumber::Chef::Config[:lab_user]}/.ssh")

      command_run_local("rm #{container_root(name)}/etc/motd")
      command_run_local("cp /etc/motd #{container_root(name)}/etc/motd")
      command_run_local("echo '    You are now logged in to the #{name} container!\n' >> #{container_root(name)}/etc/motd")
      command_run_local("sed -i 's/localhost #{name}/#{name}.test-lab #{name} localhost/' #{container_root(name)}/etc/hosts")
      command_run_local("echo '#{name}.test-lab' | tee #{container_root(name)}/etc/hostname")
    end
    container_start(name)
  end

  def container_destroy(name)
    if container_exists?(name)
      chef_server_node_destroy(name)
      chef_server_client_destroy(name)
      container_stop(name)
      command_run_local("lxc-destroy -n #{name}")
      log("destroyed container $#{name}$")
    end
  end

################################################################################

  def container_start(name)
    status = command_run_local("lxc-info -n #{name}")
    if status.include?("STOPPED")
      command_run_local("lxc-start -d -n #{name}")
    end
  end

  def container_stop(name)
    status = command_run_local("lxc-info -n #{name}")
    if status.include?("RUNNING")
      command_run_local("lxc-stop -n #{name}")
    end
  end

################################################################################

  def container_running?(name)
    status = command_run_local("lxc-info -n #{name}")
    status.include?("RUNNING")
  end

################################################################################

  def container_config_network(name)
    lxc_network_config = File.join("/etc/lxc", name)
    File.open(lxc_network_config, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("LXC Container Configuration"))
      f.puts("")
      f.puts("lxc.network.type = veth")
      f.puts("lxc.network.flags = up")
      f.puts("lxc.network.link = br0")
      f.puts("lxc.network.name = eth0")
      f.puts("lxc.network.hwaddr = #{@servers[name][:mac]}")
      f.puts("lxc.network.ipv4 = 0.0.0.0")
    end
  end

################################################################################

  def containers
    command_run_local("lxc-ls 2>&1").split("\n").uniq
  end

  def container_exists?(name)
    (File.directory?(container_root(name)) ? true : false)
  end

  def container_root(name)
    File.join("/", "var", "lib", "lxc", name, "rootfs")
  end

  def container_cache_root(name, distro, release, arch)
    case distro.downcase
    when "ubuntu" then
      cache_root = File.join("/", "var", "cache", "lxc", release, "rootfs-#{arch}")
    when "fedora" then
      cache_root = File.join("/", "var", "cache", "lxc", distro, arch, release, "rootfs")
    end
  end

  def container_create_command(name, distro, release, arch)
    case distro.downcase
    when "ubuntu" then
      "lxc-create -n #{name} -f /etc/lxc/#{name} -t #{distro} -- --release #{release} --arch #{arch}"
    when "fedora" then
      "lxc-create -n #{name} -f /etc/lxc/#{name} -t #{distro} -- --release #{release}"
    end
  end

################################################################################

end

################################################################################
