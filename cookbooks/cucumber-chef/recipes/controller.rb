directory "/root/.ssh" do
  owner "root"
  mode "0600"
end

cookbook_file "/root/.ssh/git-key.rsa" do
  source "git-private-key"
end

cookbook_file "/root/.ssh/config" do
  source "permissive-ssh-config"
end

cookbook_file "/root/.ssh/id_rsa" do
  source "cucumber-private-key"
  mode "0600"
  owner "root"
end

cookbook_file "/root/.bashrc" do
  source "add-git-identity"
end

directory "/etc/lxc"

cookbook_file "/etc/lxc/controller" do
  source "lxc-controller-network-config"
end

execute "lxc-create -n controller -f /etc/lxc/controller -t lucid-chef" do
  not_if {File.exists?("/var/lib/lxc/controller")}
end

template "/var/lib/lxc/controller/rootfs/etc/chef/client.rb" do
  source "controller-client.erb"
  variables(:orgname => node["cucumber-chef"]["orgname"])
end

cookbook_file "/var/lib/lxc/controller/rootfs/etc/chef/first-boot.json" do
  source "controller-first-boot"
end

controllers = search(:node, 'name:cucumber-chef-controller')
execute 'chroot /var/lib/lxc/controller/rootfs /bin/bash -c "chef-client -j /etc/chef/first-boot.json"' do
  action :run
  not_if { controllers.length > 0 }
end

execute 'lxc-start -d -n controller' do
  status = %x[lxc-info -n controller 2>&1]
  not_if {status.include?("RUNNING")}
end