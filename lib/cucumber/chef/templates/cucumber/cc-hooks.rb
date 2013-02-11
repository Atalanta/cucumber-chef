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
  $test_lab.containers.load

  $test_lab.containers.to_a.each do |name, value|
    $test_lab.containers.destroy(name)
  end

  File.exists?(Cucumber::Chef.containers_bin) && File.delete(Cucumber::Chef.containers_bin)
  $test_lab.containers.load
else
  $ui.logger.info { "Allowing existing containers to persist." }
end

if ENV['PUSH'] == 'YES'
  # Upload all of the chef-repo environments
  puts("  * Pushing chef-repo environments to test lab...")
  $test_lab.knife_cli(%Q{environment from file ./environments/*.rb --yes}, :silence => true)

  # Upload all of the chef-repo cookbooks
  puts("  * Pushing chef-repo cookbooks to test lab...")
  cookbook_paths = ["./cookbooks"]
  cookbook_paths << "./site-cookbooks" if Cucumber::Chef::Config.librarian_chef
  $test_lab.knife_cli(%Q{cookbook upload --all --cookbook-path #{cookbook_paths.join(':')} --force --yes}, :silence => true)

  # Upload all of the chef-repo roles
  puts("  * Pushing chef-repo roles to test lab...")
  $test_lab.knife_cli(%Q{role from file ./roles/*.rb --yes}, :silence => true)

  # Upload all of our chef-repo data bags
  Dir.glob("./data_bags/*").each do |data_bag_path|
    next if !File.directory?(data_bag_path)
    puts("  * Pushing chef-repo data bag '#{File.basename(data_bag_path)}' to test lab...")
    data_bag = File.basename(data_bag_path)
    $test_lab.knife_cli(%Q{data bag create "#{data_bag}" --yes}, :silence => true)
    $test_lab.knife_cli(%Q{data bag from file "#{data_bag}" "#{data_bag_path}" --yes}, :silence => true)
  end
end


################################################################################
# HOOKS
################################################################################

Before do |scenario|
  $scenario = scenario

  $test_lab.containers.load

  $test_lab.containers.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                              :validation_client_name => "chef-validator")
end

After do |scenario|
  $test_lab.containers.save

  $test_lab.containers.to_a.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    server_destroy(name)
  end

  @connection and @connection.ssh.shutdown!
end

################################################################################
