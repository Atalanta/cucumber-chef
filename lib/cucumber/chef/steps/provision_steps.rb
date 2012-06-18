################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
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

Given /^I have a server called "([^\"]*)"$/ do |name|
  @servers = (@servers || Hash.new(nil)).merge(name => Hash.new(nil))
end

And /^"([^\"]*)" is running "([^\"]*)" "([^\"]*)"$/ do |name, distro, release|
  @servers[name].merge!( :distro => distro, :release => release )
end

And /^"([^\"]*)" has "([^\"]*)" architecture$/ do |name, arch|
  @servers[name].merge!( :arch => arch )
end

And /^"([^\"]*)" should( not)? be persistant$/ do |name, boolean|
  @servers[name].merge!( :persist => (!boolean ? true : false) )
end

And /^"([^\"]*)" has an IP address of "([^\"]*)"$/ do |name, ip|
  @servers[name].merge!( :ip => ip )
end

And /^"([^\"]*)" has a MAC address of "([^\"]*)"$/ do |name, mac|
  @servers[name].merge!( :mac => ip )
end

And /^"([^\"]*)" has been provisioned$/ do |name|
  server_create(name, @servers[name])
end

And /^the "([^\"]*)" role has been added to the "([^\"]*)" run list$/ do |role, name|
  chef_set_client_attributes(@servers[name], :run_list => ["role[#{role}]"])
end

And /^the "([^\"]*)" recipe has been added to the "([^\"]*)" run list$/ do |recipe, name|
  chef_set_client_attributes(@servers[name], :run_list => ["recipe[#{recipe}]"])
end

And /^the chef-client has been run on "([^\"]*)"$/ do |name|
  chef_run_client(name)
end
