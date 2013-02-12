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

tag = Cucumber::Chef.tag("cucumber-chef")
puts("  * #{tag}")
Cucumber::Chef.boot(tag)

$ui = ZTK::UI.new(:logger => Cucumber::Chef.logger)
if !(($test_lab = Cucumber::Chef::TestLab.new($ui)) && $test_lab.alive?)
  message = "No running cucumber-chef test labs to connect to!"
  $ui.logger.fatal { message }
  raise message
end

if ENV['PURGE'] == 'YES'
  $ui.logger.warn { "PURGING CONTAINERS!  Container attributes will be reset!" }
  Cucumber::Chef::Container.all.each do |container|
    $test_lab.containers.destroy(container)
  end
else
  $ui.logger.info { "Allowing existing containers to persist." }
end

$test_lab.containers.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                            :validation_client_name => "chef-validator")

if ENV['SETUP'] == 'YES'
  # Upload all of the chef-repo environments
  puts("  * Pushing chef-repo environments to test lab...")
  $test_lab.knife_cli(%Q{environment from file ./environments/*.rb}, :silence => true)

  # Upload all of the chef-repo cookbooks
  puts("  * Pushing chef-repo cookbooks to test lab...")
  cookbook_paths = ["./cookbooks"]
  cookbook_paths << "./site-cookbooks" if Cucumber::Chef::Config.librarian_chef
  $test_lab.knife_cli(%Q{cookbook upload --all --cookbook-path #{cookbook_paths.join(':')} --force}, :silence => true)

  # Upload all of the chef-repo roles
  puts("  * Pushing chef-repo roles to test lab...")
  $test_lab.knife_cli(%Q{role from file ./roles/*.rb}, :silence => true)

  # Upload all of our chef-repo data bags
  Dir.glob("./data_bags/*").each do |data_bag_path|
    next if !File.directory?(data_bag_path)
    puts("  * Pushing chef-repo data bag '#{File.basename(data_bag_path)}' to test lab...")
    data_bag = File.basename(data_bag_path)
    $test_lab.knife_cli(%Q{data bag create "#{data_bag}"}, :silence => true)
    $test_lab.knife_cli(%Q{data bag from file "#{data_bag}" "#{data_bag_path}"}, :silence => true)
  end

  Cucumber::Chef::Container.all.each do |container|
    puts("  * Creating container '#{container.name}'...")
    $test_lab.containers.create(container)
    $test_lab.containers.chef_run_client(container)
  end
end


################################################################################
# HOOKS
################################################################################

Before do |scenario|
end

After do |scenario|
  @connection and @connection.ssh.shutdown!
end

################################################################################
