################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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

%w( build-essential wget chkconfig ruby-full ruby-dev libxml2-dev libxslt1-dev ).each do |p|
  package p
end

%w( root ubuntu ).each do |user|
  home_dir = (user == "root" ? "/#{user}" : "/home/#{user}")

  directory "create .ssh directory for #{user}" do
    path "#{home_dir}/.ssh"
    owner user
    group user
    mode "0700"

    not_if { File.directory?(File.join(home_dir, ".ssh")) }
  end

  template "create ssh config for #{user}" do
    path "#{home_dir}/.ssh/config"
    source "ssh-config.erb"
    owner user
    group user
    mode "0600"

    not_if { File.exists?(File.join(home_dir, ".ssh", "config")) }
  end

  template "create .gemrc for #{user}" do
    path "#{home_dir}/.gemrc"
    source "gemrc.erb"
    owner user
    group user
    mode "0644"

    not_if { File.exists?(File.join(home_dir, ".gemrc")) }
  end

  execute "generate ssh keypair for #{user}" do
    command "ssh-keygen -q -N '' -f #{home_dir}/.ssh/id_rsa"

    not_if { File.exists?(File.join(home_dir, ".ssh", "id_rsa")) }
  end

  file "ensure ssh private key ownership for #{user}" do
    path "#{home_dir}/.ssh/id_rsa"
    owner user
    group user
  end

  file "ensure ssh public key ownership for #{user}" do
    path "#{home_dir}/.ssh/id_rsa.pub"
    owner user
    group user
  end

  execute "copy public key into authorized_keys for #{user}" do
    command "cat #{home_dir}/.ssh/id_rsa.pub | tee -a #{home_dir}/.ssh/authorized_keys"

    not_if do
      %x( cat #{home_dir}/.ssh/authorized_keys | grep "`cat #{home_dir}/.ssh/id_rsa.pub`" )
      ($? == 0)
    end
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
# RUBY
################################################################################
bash "install rubygems" do
  code <<-EOH
cd /tmp
wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.19.tgz
tar zxf rubygems-1.8.19.tgz
cd rubygems-1.8.19
ruby setup.rb --no-format-executable
  EOH
end

gem_package "cucumber-chef" do
  gem_binary("/usr/bin/gem")

  version(node['cucumber_chef']['version'])

  if node['cucumber_chef']['prerelease']
    options("--prerelease")
  end
end

%w( rspec ).each do |g|
  gem_package g do
    gem_binary("/usr/bin/gem")
  end
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


################################################################################
# CHEF-SOLR / APACHE SOLR
################################################################################

template "install custom solr config" do
  path "/var/lib/chef/solr/conf/solrconfig.xml"
  source "solrconfig.erb"
  owner "chef"
  group "chef"
  mode "0644"
end
