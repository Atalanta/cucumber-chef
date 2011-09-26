%w{lxc bridge-utils debootstrap}.each do |pkg|
  package "#{pkg}"
end

bash "Set up networking" do
  code <<-EOH
brctl addbr br0
ifconfig br0 192.168.20.1 up
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
EOH
  not_if "ip link ls dev br0"
end

directory "/cgroup" do
  action :create
end

mount "/cgroup" do
  device "cgroup"
  fstype "cgroup"
  pass 0
  action [:mount, :enable]
end

template "/usr/bin/lxc-lucid-chef" do
  source "lxc-lucid-chef"
  mode "0755"
  variables( :orgname => node["cucumber-chef"]["orgname"] )
  action :create
end




