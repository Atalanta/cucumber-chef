################################################################################
#
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


%w(lxc bridge-utils debootstrap yum isc-dhcp-server bind9 ntpdate ntp).each do |p|
  package p
end


################################################################################
# APPARMOR
################################################################################
service "apparmor"

bash "configure apparmor so dhcp3 can read /etc/bind" do
  code <<-EOH
cat <<EOF >> /etc/apparmor.d/local/usr.sbin.dhcpd
/etc/bind/ r,
/etc/bind/** r,
EOF
  EOH

  notifies :restart, "service[apparmor]"

  not_if do
    %x( cat /etc/apparmor.d/local/usr.sbin.dhcpd3 | grep "\/etc\/bind\/" )
    ($? == 0)
  end
end


################################################################################
# NETWORKING
################################################################################
service "networking"

execute "add local bind to dhclient" do
  command "sed -i \"s/#prepend domain-name-servers 127.0.0.1;/prepend domain-name-servers 127.0.0.1;\\nsupersede domain-name \\\"test-lab\\\";\\nsupersede domain-search \\\"test-lab\\\";/\" /etc/dhcp/dhclient.conf"

  notifies :restart, "service[networking]"

  only_if do
    %x( cat /etc/dhcp/dhclient.conf | grep "#prepend domain-name-servers 127.0.0.1;" )
    ($? == 0)
  end
end

bash "configure bridge interface" do
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

  notifies :restart, "service[networking]"

  not_if do
    %x( cat /etc/network/interfaces | grep "iface br0 inet static" )
    ($? == 0)
  end
end

execute "enable ipv4 packet forwarding" do
  command "sysctl -w net.ipv4.ip_forward=1"

  notifies :restart, "service[networking]"

  not_if do
    %x( sysctl net.ipv4.ip_forward | grep "net.ipv4.ip_forward = 1" )
    ($? == 0)
  end
end

execute "enable nat for outbound traffic" do
  command "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"

  notifies :restart, "service[networking]"

  not_if do
    %x( iptables -t nat --list | grep "MASQUERADE" )
    ($? == 0)
  end
end


################################################################################
# BIND9
################################################################################
service "bind9"

file "make mode on rndc.key o+r" do
  path "/etc/bind/rndc.key"
  mode 0644

  notifies :restart, "service[bind9]"

  not_if { ("%o" % File.stat("/etc/bind/rndc.key").mode) == "100644" }
end

template "setup our bind9 zone and controls configuration" do
  path "/etc/bind/named.conf.test-lab"
  source "named-conf-local.erb"
  owner "root"
  group "bind"
  mode "0644"

  notifies :restart, "service[bind9]"

  not_if { File.exists?("/etc/bind/named.conf.test-lab") }
end

bash "inject test-lab bind9 configuration" do
  code <<-EOH
cat <<EOF >> /etc/bind/named.conf
include "/etc/bind/named.conf.test-lab";
EOF
  EOH

  notifies :restart, "service[bind9]"

  not_if do
    %x( cat /etc/bind/named.conf | grep "\/etc\/bind\/named\.conf\.test-lab" )
    ($? == 0)
  end
end

template "create test-lab zone file" do
  path "/var/lib/bind/db.test-lab"
  source "db-test-lab.erb"
  owner "root"
  group "bind"
  mode "0644"

  notifies :restart, "service[bind9]"

  not_if { File.exists?("/var/lib/bind/db.test-lab") }
end

template "create 168.192 zone file" do
  path "/var/lib/bind/db.168.192"
  source "db-168-192.erb"
  owner "root"
  group "bind"
  mode "0644"

  notifies :restart, "service[bind9]"

  not_if { File.exists?("/var/lib/bind/db.168.192") }
end


################################################################################
# ISC-DHCP-SERVER
################################################################################
service "isc-dhcp-server"

file "touch our dhcp3 include file" do
  path "/etc/dhcp/test-lab.conf"
  action :touch

  notifies :restart, "service[isc-dhcp-server]"

  not_if { File.exists?("/etc/dhcp/test-lab.conf") }
end

template "configure isc-dhcp-server for test-lab" do
  path "/etc/dhcp/dhcpd.conf"
  source "dhcpd-conf.erb"
  owner "root"
  group "root"
  mode "0644"

  notifies :restart, "service[isc-dhcp-server]"

  not_if do
    %x( cat /etc/dhcp/dhcpd.conf | grep "\/etc\/dhcp\/test-lab\.conf" )
    ($? == 0)
  end
end

execute "configure isc-dhcp-server listener interface" do
  command "sed -i \"s/INTERFACES=\\\"\\\"/INTERFACES=\\\"br0\\\"/\" /etc/default/isc-dhcp-server"

  notifies :restart, "service[isc-dhcp-server]"

  not_if do
    %x( cat /etc/default/isc-dhcp-server | grep "INTERFACES=\\\"br0\\\"" )
    ($? == 0)
  end
end


################################################################################
# LXC
################################################################################
service "lxc-net"
service "lxc"

execute "set LXC_AUTO to false" do
  command "sed -i \"s/LXC_AUTO=\\\"true\\\"/LXC_AUTO=\\\"false\\\"/\" /etc/default/lxc"

  notifies :stop, "service[lxc-net]"

  only_if do
    %x( cat /etc/default/lxc | grep "LXC_AUTO=\\\"true\\\"" )
    ($? == 0)
  end
end

execute "set USE_LXC_BRIDGE to false" do
  command "sed -i \"s/USE_LXC_BRIDGE=\\\"true\\\"/USE_LXC_BRIDGE=\\\"false\\\"/\" /etc/default/lxc"

  notifies :stop, "service[lxc-net]"

  only_if do
    %x( cat /etc/default/lxc | grep "USE_LXC_BRIDGE=\\\"true\\\"" )
    ($? == 0)
  end
end

directory "create lxc configuration directory" do
  path "/etc/lxc"

  not_if { File.exists?("/etc/lxc") && File.directory?("/etc/lxc") }
end
