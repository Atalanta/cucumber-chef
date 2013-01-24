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

module Cucumber::Chef::Helpers::Container

################################################################################

  def load_containers
    if File.exists?(Cucumber::Chef.containers_bin)
      @containers = ((Marshal.load(IO.read(Cucumber::Chef.containers_bin)) rescue Hash.new) || Hash.new)
      @containers.each do |key, value|
        $logger.info { "LOAD CONTAINER: #{key.inspect} => #{value.inspect}" }
      end
    else
      $logger.info { "INITIALIZED: '#{Cucumber::Chef.containers_bin}'." }
    end
  end

################################################################################

  def save_containers
    @containers.each do |key, value|
      $logger.debug { "SAVE CONTAINER: #{key.inspect} => #{value.inspect}" }
    end

    File.open(Cucumber::Chef.containers_bin, 'w') do |f|
      f.puts(Marshal.dump(@containers))
    end
  end

################################################################################

  def container_create(name, distro, release, arch)
    unless container_exists?(name)
      cache_rootfs = container_cache_root(name, distro, release, arch)
      if !File.exists?(cache_rootfs)
        logger.warn { "'#{name}' has triggered building the lxc file cache for '#{distro}'." }
        logger.warn { "This one time process per distro can take up to 10 minutes or longer depending on the test lab." }
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
        command_run_local("chroot #{cache_rootfs} /bin/bash -c 'locale-gen en_US'")
        command_run_local("chroot #{cache_rootfs} /bin/bash -c 'wget http://www.opscode.com/chef/install.sh -O - | bash'")
        if distro.downcase == "fedora"
          command_run_local("chroot #{cache_rootfs} /bin/bash -c 'rpm -Uvh --nodeps /tmp/*rpm'")
        end
        command_run_local("lxc-destroy -n #{name}")
        command_run_local(container_create_command(name, distro, release, arch))
      end

      command_run_local("mkdir -p #{File.join(container_root(name), Cucumber::Chef.lxc_user_home_dir, ".ssh")}")
      command_run_local("chmod 0700 #{File.join(container_root(name), Cucumber::Chef.lxc_user_home_dir, ".ssh")}")
      command_run_local("cat #{File.join(Cucumber::Chef.lab_user_home_dir, ".ssh", "id_rsa.pub")} | tee -a #{File.join(container_root(name), Cucumber::Chef.lxc_user_home_dir, ".ssh", "authorized_keys")}")

      command_run_local("rm -f #{File.join(container_root(name), "etc", "motd")}")
      command_run_local("cp /etc/motd #{File.join(container_root(name), "etc", "motd")}")
      command_run_local("echo '    You are now logged in to the #{name} container!\n' >> #{File.join(container_root(name), "etc", "motd")}")
      command_run_local("echo '127.0.0.1 #{name}.#{Cucumber::Chef::Config.test_lab[:tld]} #{name}' | tee -a #{File.join(container_root(name), "etc", "hosts")}")
      command_run_local("echo '#{name}.test-lab' | tee #{File.join(container_root(name), "etc", "hostname")}")
    end
    container_start(name)
  end

  def container_destroy(name)
    if container_exists?(name)
      chef_server_node_destroy(name)
      chef_server_client_destroy(name)
      container_stop(name)
      command_run_local("lxc-destroy -n #{name}")
      logger.info { "Destroyed container '#{name}'." }
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
      f.puts("lxc.network.hwaddr = #{@containers[name][:mac]}")
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
