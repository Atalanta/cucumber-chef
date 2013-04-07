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


################################################################################
# SYSTEM TWEAKS
################################################################################

%w(build-essential wget chkconfig).each do |p|
  package p
end

[ node.cucumber_chef.lab_user, node.cucumber_chef.lxc_user ].each do |username|
  home_dir = ((username.downcase == "root") ? "/#{username}" : "/home/#{username}")

  user username do
    comment username
    home home_dir
    shell "/bin/bash"
    supports :manage_home => true
  end

  directory "create home directory for #{username}" do
    path home_dir
    owner username
    group username
    mode "0700"

    not_if { File.directory?(File.join(home_dir)) }
  end

  directory "create .ssh directory for #{username}" do
    path "#{home_dir}/.ssh"
    owner username
    group username
    mode "0700"

    not_if { File.directory?(File.join(home_dir, ".ssh")) }
  end

  template "create ssh config for #{username}" do
    path "#{home_dir}/.ssh/config"
    source "ssh-config.erb"
    owner username
    group username
    mode "0600"

    not_if { File.exists?(File.join(home_dir, ".ssh", "config")) }
  end

  execute "generate ssh keypair for #{username}" do
    command "ssh-keygen -q -N '' -f #{home_dir}/.ssh/id_rsa"

    not_if { File.exists?(File.join(home_dir, ".ssh", "id_rsa")) }
  end

  file "ensure ssh private key ownership for #{username}" do
    path "#{home_dir}/.ssh/id_rsa"
    owner username
    group username
    mode "0400"
  end

  file "ensure ssh public key ownership for #{username}" do
    path "#{home_dir}/.ssh/id_rsa.pub"
    owner username
    group username
  end

  execute "copy public key into authorized_keys for #{username}" do
    command "cat #{home_dir}/.ssh/id_rsa.pub | tee -a #{home_dir}/.ssh/authorized_keys"

    not_if do
      %x( cat #{home_dir}/.ssh/authorized_keys | grep "`cat #{home_dir}/.ssh/id_rsa.pub`" )
      ($? == 0)
    end
  end

  file "ensure ssh authorized_keys ownership for #{username}" do
    path "#{home_dir}/.ssh/authorized_keys"
    owner username
    group username
  end

end

file "remove update-motd" do
  path "/etc/motd"
  action :delete

  only_if { File.exists?("/etc/motd") && File.symlink?("/etc/motd") }
end

template "install cucumber-chef motd" do
  path "/etc/motd"
  source "motd.erb"
  owner "root"
  group "root"
  mode "0644"

  not_if { File.exists?("/etc/motd") && !File.symlink?("/etc/motd") }
end


################################################################################
# CHEF-CLIENT
################################################################################
service "chef-client"

execute "set chef-client logging to debug" do
  command "sed -i \"s/log_level          :info/log_level          :debug/\" /etc/chef/client.rb"

  notifies :restart, "service[chef-client]"

  only_if do
    %x( cat /etc/chef/client.rb | grep "log_level          :info" )
    ($? == 0)
  end
end
