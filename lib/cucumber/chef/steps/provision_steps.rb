################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
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

Given /^I have a server called "([^\"]*)"$/ do |name|
  $test_lab.drb.server_init(name)
end

And /^"([^\"]*)" is running "([^\"]*)" "([^\"]*)"$/ do |name, distro, release|
  $test_lab.drb.server_set_attributes(name, :distro => distro, :release => release)
end

And /^"([^\"]*)" has "([^\"]*)" architecture$/ do |name, arch|
  $test_lab.drb.server_set_attributes(name, :arch => arch)
end

And /^"([^\"]*)" should( not)? be persist[ae]nt$/ do |name, boolean|
  $test_lab.drb.server_set_attributes(name, :persist => (!boolean ? true : false))
end

And /^"([^\"]*)" has an IP address of "([^\"]*)"$/ do |name, ip|
  $test_lab.drb.server_set_attributes(name, :ip => ip)
end

And /^"([^\"]*)" has a MAC address of "([^\"]*)"$/ do |name, mac|
  $test_lab.drb.server_set_attributes(name, :mac => mac)
end

And /^"([^\"]*)" has been provisioned$/ do |name|
  $test_lab.drb.server_create(name)
end

And /^the "([^\"]*)" role has been added to the "([^\"]*)" run list$/ do |role, name|
  $test_lab.drb.chef_set_client_attributes(name, :run_list => ["role[#{role}]"])
end

And /^the "([^\"]*)" recipe has been added to the "([^\"]*)" run list$/ do |recipe, name|
  $test_lab.drb.chef_set_client_attributes(name, :run_list => ["recipe[#{recipe}]"])
end

And /^"([^\"]*)" is in the "([^\"]*)" environment$/ do |name, environment|
  $test_lab.drb.chef_set_client_config(:environment => environment)
end

And /^the chef-client has been run on "([^\"]*)"$/ do |name|
  $test_lab.knife_cli(%Q{index rebuild --yes --verbose})
  $test_lab.drb.chef_run_client(name)
  chef_client_artifacts(name)
end
