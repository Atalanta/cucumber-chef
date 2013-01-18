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

$logger = ZTK::Logger.new(Cucumber::Chef.log_file)
Cucumber::Chef.is_rc? and ($logger.level = ZTK::Logger::DEBUG)

message = "cucumber-chef v#{Cucumber::Chef::VERSION}"
print("  * #{message}")
$logger.info { message }

Cucumber::Chef::Config.load
if ($test_lab = Cucumber::Chef::TestLab.new) && ($test_lab.labs_running.count > 0)

  # load our test lab knife config
  knife_rb = Cucumber::Chef.locate(:file, ".cucumber-chef", "knife.rb")
  Chef::Config.from_file(knife_rb)
  Chef::Config[:chef_server_url] = "http://#{$test_lab.labs_running.first.public_ip_address}:4000"

  # fire up our drb server
  ssh = ZTK::SSH.new
  ssh.config.host_name = $test_lab.labs_running.first.public_ip_address
  ssh.config.user = Cucumber::Chef::Config[:lab_user]
  ssh.config.keys = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{ssh.config.user}")
  ssh.exec("nohup sudo /bin/bash -c 'pkill -9 -f cc-server'")
  ssh.exec("nohup sudo /bin/bash -c 'BACKGROUND=yes cc-server #{Cucumber::Chef.external_ip}'")
  Cucumber::Chef.spinner do
    ZTK::TCPSocketCheck.new(:host => $test_lab.labs_running.first.public_ip_address, :port => 8787, :data => "\n\n").wait
  end

  # initialize our drb object
  $drb_test_lab ||= DRbObject.new_with_uri("druby://#{$test_lab.labs_running.first.public_ip_address}:8787")
  $drb_test_lab and DRb.start_service
  $drb_test_lab.servers = Hash.new(nil)

  FileUtils.rm_rf(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "artifacts"))
else
  puts("No running cucumber-chef test labs to connect to!")
  exit(1)
end
puts(" - connected to test lab")


################################################################################
# BEFORE HOOK
################################################################################

Before do |scenario|
  # store the current scenario here; espcially since I don't know a better way to get at this information
  # we use various aspects of the scenario to name our artifacts
  $scenario = scenario

  $servers_bin ||= (File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "servers.bin") rescue File.expand_path(File.join(ENV['HOME'], "servers.bin")))

  # cleanup previous lxc containers if asked
  if ENV['DESTROY']
    log("servers", "are being destroyed")
    $drb_test_lab.servers.each do |name|
      $drb_test_lab.server_destroy(name)
    end
    File.exists?($servers_bin) && File.delete($servers_bin)
  else
    log("servers", "are being preserved")
  end

  if File.exists?($servers_bin)
    $drb_test_lab.servers = (Marshal.load(IO.read($servers_bin)) rescue Hash.new(nil))
  end

  $drb_test_lab.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                       :validation_client_name => "chef-validator")
end


################################################################################
# AFTER HOOK
################################################################################

After do |scenario|
  File.open($servers_bin, 'w') do |f|
    f.puts(Marshal.dump($drb_test_lab.servers))
  end

  # cleanup non-persistent lxc containers between tests
  $drb_test_lab.servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    $drb_test_lab.server_destroy(name)
  end
end


################################################################################
# EXIT HOOK
################################################################################

Kernel.at_exit do
  $drb_test_lab.shutdown
end

################################################################################
