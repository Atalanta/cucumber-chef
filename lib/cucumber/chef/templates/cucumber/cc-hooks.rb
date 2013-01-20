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
puts("  * #{message}")
$logger.info { message }

Cucumber::Chef::Config.load
if ($test_lab = Cucumber::Chef::TestLab.new) && ($test_lab.labs_running.count > 0)

  # load our test lab knife config
  Chef::Config.from_file(Cucumber::Chef.knife_rb)
  Chef::Config[:chef_server_url] = "http://#{$test_lab.labs_running.first.public_ip_address}:4000"

  # fire up our drb server
  $test_lab.ssh.exec("sudo mkdir -p /home/#{$test_lab.ssh.config.user}/.cucumber-chef")
  $test_lab.ssh.exec("sudo cp -f /home/#{$test_lab.ssh.config.user}/.chef/knife.rb /home/#{$test_lab.ssh.config.user}/.cucumber-chef/knife.rb")
  $test_lab.ssh.exec("sudo chown -R #{$test_lab.ssh.config.user}:#{$test_lab.ssh.config.user} /home/#{$test_lab.ssh.config.user}/.cucumber-chef")

  local_file = Cucumber::Chef.config_rb
  remote_file = File.join("/", "home", $test_lab.ssh.config.user, ".cucumber-chef", "config.rb")
  $test_lab.ssh.upload(local_file, remote_file)

  $cc_server_thread = Thread.new do
    $test_lab.ssh.exec("sudo pkill -9 -f cc-server")
    $test_lab.ssh.exec("sudo cc-server #{Cucumber::Chef.external_ip}", :silence => false)

    Kernel.at_exit do
      $test_lab.ssh.close
    end
  end

  # Cucumber::Chef.spinner do
  ZTK::TCPSocketCheck.new(:host => $test_lab.labs_running.first.public_ip_address, :port => 8787, :data => "\n\n").wait
  # end

  # initialize our drb object
  $test_lab.drb

  FileUtils.rm_rf(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "artifacts"))
else
  puts("  X No running cucumber-chef test labs to connect to!")
  exit(1)
end


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
    $test_lab.drb.servers.each do |name|
      $test_lab.drb.server_destroy(name)
    end
    File.exists?($servers_bin) && File.delete($servers_bin)
  else
    log("servers", "are being preserved")
  end

  if File.exists?($servers_bin)
    $test_lab.drb.servers = (Marshal.load(IO.read($servers_bin)) rescue Hash.new(nil))
  end

  $test_lab.drb.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                       :validation_client_name => "chef-validator")
end


################################################################################
# AFTER HOOK
################################################################################

After do |scenario|
  File.open($servers_bin, 'w') do |f|
    f.puts(Marshal.dump($test_lab.drb.servers))
  end

  # cleanup non-persistent lxc containers between tests
  $test_lab.drb.servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    $test_lab.drb.server_destroy(name)
  end
end


################################################################################
# EXIT HOOK
################################################################################

Kernel.at_exit do
  $test_lab.drb.shutdown
  $cc_server_thread.kill
end

################################################################################
