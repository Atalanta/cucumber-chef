%w{lxc bridge-utils debootstrap}.each do |p|
  package p
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

# install our lxc container creation template
template "/usr/lib/lxc/templates/lxc-lucid-chef" do
  source "lxc-lucid-chef.erb"
  mode "0755"
end
