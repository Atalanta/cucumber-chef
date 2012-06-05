################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
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

  def container_create(name)
    unless container_exists?(name)
      command_run_local("lxc-create -n #{name} -f /etc/lxc/#{name} -t ubuntu")
      command_run_local("mkdir -p #{container_root(name)}/root/.ssh/")
      command_run_local("chmod 0700 #{container_root(name)}/root/.ssh/")
      command_run_local("cat /root/.ssh/id_rsa.pub > #{container_root(name)}/root/.ssh/authorized_keys")
      command_run_local("cat /home/ubuntu/.ssh/id_rsa.pub >> #{container_root(name)}/root/.ssh/authorized_keys")

      command_run_local("rm #{container_root(name)}/etc/motd")
      command_run_local("cp /etc/motd #{container_root(name)}/etc/motd")
      command_run_local("echo \"    You are now logged in to the LXC '#{name}'\\n\" >> #{container_root(name)}/etc/motd")
      command_run_local("sed -i \"s/localhost #{name}/#{name}.test-lab #{name} localhost/\" #{container_root(name)}/etc/hosts")
      command_run_local("echo \"#{name}.test-lab\" | tee #{container_root(name)}/etc/hostname")
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

  def container_running?(name)
    status = command_run_local("lxc-info -n #{name} 2>&1")
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

################################################################################
