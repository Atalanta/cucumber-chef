#
# Author:: Zachary Patten (<zpatten@jovelabs.com>)
# Cookbook Name:: cucumber-chef
# Recipe:: lxc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


%w(lxc bridge-utils debootstrap dhcp3-server bind9).each do |p|
  package p
end

# modify mode on rndc.key so dhcp3-server can read it
file "/etc/bind/rndc.key" do
  mode 0644

  not_if { ("%o" % File.stat("/etc/bind/rndc.key").mode) == "100644" }
end

bash "configure apparmor so dhcp3-server can access rndc.key" do
  code <<-EOH
cat <<EOF >> /etc/apparmor.d/local/usr.sbin.dhcpd3
/etc/bind/ r,
/etc/bind/** r,
EOF
  EOH

  notifies :restart, "service[apparmor]", :immediately

  not_if do
    %x(cat /etc/apparmor.d/local/usr.sbin.dhcpd3 | grep "\/etc\/bind\/")
    ($? == 0)
  end
end

service "apparmor"

# configure dhcp3-server for lxc
bash "configure dhcp3-server" do
  code <<-EOH
cat <<EOF > /etc/dhcp3/dhcpd.conf
ddns-update-style none;
include "/etc/bind/rndc.key";

default-lease-time 600;
max-lease-time 7200;

authoritative;

log-facility local7;

include "/etc/dhcp3/lxc.conf";
EOF
  EOH

  not_if do
    %x(cat /etc/dhcp3/dhcpd.conf | grep "\/etc\/dhcp3\/lxc\.conf")
    ($? == 0)
  end
end

# configure bridge-utils for lxc
bash "configure bridge-utils" do
  code <<-EOH
cat <<EOF >> /etc/network/interfaces

# The bridge network interface
auto br0
iface br0 inet static
address 192.168.255.254
netmask 255.255.0.0
pre-up brctl addbr br0
post-down brctl delbr br0
EOF
  EOH

  not_if "ip link ls dev br0"
end

# enable ipv4 packet forwarding
execute "sysctl -w net.ipv4.ip_forward=1" do
  not_if "ip link ls dev br0"
end

# enable nat'ing of all outbound traffic
execute "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" do
  not_if "ip link ls dev br0"
end

# restart the network so our changes take immediate effect
execute "/etc/init.d/networking restart" do
  not_if "ip link ls dev br0"
end

# create the cgroup device
directory "/cgroup" do
  not_if { File.directory?(File.join("/", "cgroup")) }
end

mount "/cgroup" do
  device "cgroup"
  fstype "cgroup"
  pass 0
  action [:mount, :enable]

  not_if do
    %x(mount | grep "cgroup")
    ($? == 0)
  end
end

# create a configuration directory for lxc
directory "/etc/lxc"

# load the chef client into our distro lxc cache
install_chef_sh = "/tmp/install-chef.sh"
distros = %w(ubuntu)
arch = (%x(arch).include?("i686") ? "i386" : "amd64")

template "/etc/lxc/initializer" do
  source "lxc-initializer-config.erb"

  not_if { File.exists?("/etc/lxc/initializer") }
end

distros.each do |distro|
  cache_rootfs = File.join("/", "var", "cache", "lxc", distro, "rootfs-#{arch}")
  initializer_rootfs = File.join("/", "var", "lib", "lxc", "initializer", "rootfs")

  execute "lxc-create -n initializer -f /etc/lxc/initializer -t #{distro}" do
    not_if { File.directory?(cache_rootfs) }
  end

  execute "lxc-destroy -n initializer" do
    only_if { File.directory?(initializer_rootfs) }
  end

  template "#{cache_rootfs}#{install_chef_sh}" do
    source "lxc-install-chef.erb"
    mode "0755"

    not_if { File.exists?(File.join(cache_rootfs, install_chef_sh)) }
  end

  execute "chroot #{cache_rootfs} /bin/bash -c '#{install_chef_sh}'" do
    not_if { File.exists?(File.join(cache_rootfs, "opt", "opscode", "bin", "chef-client")) }
  end
end
