#
# Author:: Zachary Patten (<zpatten@jovelabs.com>)
# Cookbook Name:: cucumber-chef
# Recipe:: test_lab
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


%w(build-essential wget ruby-full ruby-dev libxml2-dev libxslt1-dev).each do |p|
  package p
end

bash "install rubygems" do
  code <<-EOH
cd /tmp
wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.19.tgz
tar zxf rubygems-1.8.19.tgz
cd rubygems-1.8.19
ruby setup.rb --no-format-executable
  EOH
end

%w(rspec cucumber-chef).each do |g|
  gem_package g do
    gem_binary("/usr/bin/gem")
  end
end

%w(root ubuntu).each do |user|
  home_dir = (user == "root" ? "/#{user}" : "/home/#{user}")
  directory "#{home_dir}/.ssh" do
    owner user
    group user
    mode "0700"

    not_if { File.directory?(File.join(home_dir, ".ssh")) }
  end

  template "#{home_dir}/.ssh/config" do
    source "ssh-config.erb"
    owner user
    group user
    mode "0600"

    not_if { File.exists?(File.join(home_dir, ".ssh", "config")) }
  end

  template "#{home_dir}/.gemrc" do
    source "gemrc.erb"
    owner user
    group user
    mode "0644"

    not_if { File.exists?(File.join(home_dir, ".gemrc")) }
  end

  execute "ssh-keygen -q -N '' -f #{home_dir}/.ssh/id_rsa" do
    not_if { File.exists?(File.join(home_dir, ".ssh", "id_rsa")) }
  end
end
