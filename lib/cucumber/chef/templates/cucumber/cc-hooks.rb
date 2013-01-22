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

tag = Cucumber::Chef.tag("cucumber-chef")
puts("  * #{tag}")
Cucumber::Chef.boot(tag)

if ($test_lab = Cucumber::Chef::TestLab.new) && ($test_lab.labs_running.count > 0)
  $test_lab.ssh.exec("sudo mkdir -p /home/#{$test_lab.ssh.config.user}/.cucumber-chef")
  $test_lab.ssh.exec("sudo cp -f /home/#{$test_lab.ssh.config.user}/.chef/knife.rb /home/#{$test_lab.ssh.config.user}/.cucumber-chef/knife.rb")
  $test_lab.ssh.exec("sudo chown -R #{$test_lab.ssh.config.user}:#{$test_lab.ssh.config.user} /home/#{$test_lab.ssh.config.user}/.cucumber-chef")

  local_file = Cucumber::Chef.config_rb
  remote_file = File.join("/", "home", $test_lab.ssh.config.user, ".cucumber-chef", "config.rb")
  $test_lab.ssh.upload(local_file, remote_file)

  $cc_server_thread = Thread.new do
    $test_lab.ssh.exec("sudo pkill -9 -f cc-server")

    destroy = (ENV['DESTROY'] == '1' ? 'DESTROY="1"' : nil)
    verbose = (ENV['VERBOSE'] == '1' ? 'VERBOSE="1"' : nil)
    command = ["sudo", destroy, verbose, "cc-server", Cucumber::Chef.external_ip].compact.join(" ")
    $test_lab.ssh.exec(command, :silence => false)

    Kernel.at_exit do
      $test_lab.ssh.close
    end
  end

  ZTK::TCPSocketCheck.new(:host => $test_lab.public_ip, :port => 8787, :data => "\n\n").wait

  FileUtils.rm_rf(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "artifacts"))
else
  message = "No running cucumber-chef test labs to connect to!"
  Cucumber::Chef.logger.fatal { message }
  raise message
end


################################################################################
# BEFORE HOOK
################################################################################

Before do |scenario|
  # store the current scenario here; espcially since I don't know a better way to get at this information
  # we use various aspects of the scenario to name our artifacts
  $scenario = scenario

  # cleanup previous lxc containers if asked
  if ENV['DESTROY']
    log("$containers$ are being destroyed")
    $test_lab.drb.servers.each do |name, value|
      $test_lab.drb.server_destroy(name)
    end
    File.exists?(Cucumber::Chef.servers_bin) && File.delete(Cucumber::Chef.servers_bin)
  else
    log("$containers$ are being persisted")
  end

  if File.exists?(Cucumber::Chef.servers_bin)
    $test_lab.drb.servers = (Marshal.load(IO.read(Cucumber::Chef.servers_bin)) rescue Hash.new(nil))
  end

  $test_lab.drb.chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                                       :validation_client_name => "chef-validator")
end


################################################################################
# AFTER HOOK
################################################################################

After do |scenario|
  File.open(Cucumber::Chef.servers_bin, 'w') do |f|
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
