module Cucumber::Chef::Helpers::Container

################################################################################

  def container_create(name)
    unless container_exists?(name)
      command_run_local("lxc-create -n #{name} -f /etc/lxc/#{name} -t ubuntu 2>&1")
      command_run_local("mkdir -p #{container_root(name)}/root/.ssh/ 2>&1")
      command_run_local("chmod 0700 #{container_root(name)}/root/.ssh/ 2>&1")
      command_run_local("cat /root/.ssh/id_rsa.pub > #{container_root(name)}/root/.ssh/authorized_keys 2>&1")
    end
    container_start(name)
  end

  def container_destroy(name)
    if container_exists?(name)
      container_stop(name)
      command_run_local("lxc-destroy -n #{name} 2>&1")
      chef_server_node_destroy(name)
      chef_server_client_destroy(name)
    end
  end

################################################################################

  def container_start(name)
    status = command_run_local("lxc-info -n #{name} 2>&1")
    if status.include?("STOPPED")
      command_run_local("lxc-start -d -n #{name}")
    end
  end

  def container_stop(name)
    status = command_run_local("lxc-info -n #{name} 2>&1")
    if status.include?("RUNNING")
      command_run_local("lxc-stop -n #{name}")
    end
  end

################################################################################

  def container_config_network(name)
    lxc_network_config = File.join("/etc/lxc", name)
    File.open(lxc_network_config, 'w') do |f|
      f.puts("lxc.network.type = veth")
      f.puts("lxc.network.flags = up")
      f.puts("lxc.network.link = br0")
      f.puts("lxc.network.name = eth0")
      f.puts("lxc.network.hwaddr = #{$servers[name][:mac]}")
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

################################################################################

end
