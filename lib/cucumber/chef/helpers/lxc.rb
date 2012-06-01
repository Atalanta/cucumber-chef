module Cucumber::Chef::Helpers::LXC

  def create_container(name)
    unless container_exists?(name)
      run_command("lxc-create -n #{name} -f /etc/lxc/#{name} -t ubuntu 2>&1")
      run_command("mkdir -p #{lxc_rootfs(name)}/root/.ssh/ 2>&1")
      run_command("chmod 0700 #{lxc_rootfs(name)}/root/.ssh/ 2>&1")
      run_command("cat /root/.ssh/id_rsa.pub > #{lxc_rootfs(name)}/root/.ssh/authorized_keys 2>&1")
    end
    start_container(name)
  end

  def destroy_container(name)
    stop_container(name)
    if container_exists?(name)
      run_command("lxc-destroy -n #{name} 2>&1")
    end
  end

  def container_exists?(name)
    (File.directory?(lxc_rootfs(name)) ? true : false)
  end

  def start_container(name)
    status = run_command("lxc-info -n #{name} 2>&1")
    if status.include?("STOPPED")
      run_command("lxc-start -d -n #{name}")
    end
  end

  def stop_container(name)
    status = run_command("lxc-info -n #{name} 2>&1")
    if status.include?("RUNNING")
      run_command("lxc-stop -n #{name}")
    end
  end

  def list_containers
    run_command("lxc-ls 2>&1").split("\n").uniq
  end

  def lxc_rootfs(name)
    File.join("/", "var", "lib", "lxc", name, "rootfs")
  end

  def create_network_config(name)
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

end
