%w(lxc bridge-utils debootstrap dhcp3-server).each do |p|
  package p
end

# configure dhcp3-server for lxc
bash "configure dhcp3-server" do
  code <<-EOH
cat <<EOF > /etc/dhcp3/dhcpd.conf
ddns-update-style none;

default-lease-time 600;
max-lease-time 7200;
log-facility local7;

include "/etc/dhcp3/lxc.conf";
EOF
  EOH
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
directory "/cgroup"

mount "/cgroup" do
  device "cgroup"
  fstype "cgroup"
  pass 0
  action [:mount, :enable]
end

# create a configuration directory for lxc
directory "/etc/lxc"

# load the chef client into our distro lxc cache
INSTALL_CHEF_SH = "/tmp/install-chef.sh"
DISTROS = %w(ubuntu)
ARCH = (%x(arch).include?("i686") ? "i386" : "amd64")

cookbook_file "/etc/lxc/initializer" do
  source "lxc-initializer-config"
end

DISTROS.each do |distro|
  cache_rootfs = "/var/cache/lxc/#{distro}/rootfs-#{ARCH}"

  # initialize lxc's distro cache
  execute "lxc-create -n initializer -f /etc/lxc/initializer -t #{distro}"

  execute "lxc-destroy -n initializer"

  cookbook_file "#{cache_rootfs}#{INSTALL_CHEF_SH}" do
    source "lxc-install-chef"
    mode "0755"
  end

  execute "chroot #{cache_rootfs} /bin/bash -c '#{INSTALL_CHEF_SH}'"
end
