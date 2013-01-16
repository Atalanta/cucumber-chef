require 'rspec/expectations'
require 'cucumber/chef'
require 'cucumber/chef/helpers'
require 'cucumber/chef/steps'

class CustomWorld
  include Cucumber::Chef
  include Cucumber::Chef::Helpers
end

World do
  CustomWorld.new
end

################################################################################

$logger = ZTK::Logger.new(Cucumber::Chef.log_file)
Cucumber::Chef.is_rc? and ($logger.level = ZTK::Logger::DEBUG)

message = "cucumber-chef v#{Cucumber::Chef::VERSION}"
print("  * #{message}")
$logger.info { message }

Cucumber::Chef::Config.load
if ($test_lab = Cucumber::Chef::TestLab.new) && ($test_lab.labs_running.count > 0)

  # fire up our drb server
  ssh = ZTK::SSH.new
  ssh.config.host_name = $test_lab.labs_running.first.public_ip_address
  ssh.config.user = "ubuntu"
  ssh.config.keys = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{ssh.config.user}")
  ssh.exec("nohup sudo /bin/bash -c 'pkill -9 -f cc-server'")
  ssh.exec("nohup sudo /bin/bash -c 'BACKGROUND=yes cc-server #{Cucumber::Chef.external_ip}'")
  Cucumber::Chef.spinner do
    ZTK::TCPSocketCheck.new(:host => $test_lab.labs_running.first.public_ip_address, :port => 8787, :data => "\n\n").wait
  end

  # load our test lab knife config
  knife_rb = Cucumber::Chef.locate(:file, ".cucumber-chef", "knife.rb")
  Chef::Config.from_file(knife_rb)
  Chef::Config[:chef_server_url] = "http://#{$test_lab.labs_running.first.public_ip_address}:4000"

  # initialize our drb object
  $drb_test_lab ||= DRbObject.new_with_uri("druby://#{$test_lab.labs_running.first.public_ip_address}:8787")
  $drb_test_lab and DRb.start_service
  $drb_test_lab.servers = Hash.new(nil)

else
  puts("No running cucumber-chef test labs to connect to!")
  exit(1)
end

puts(" - connected to test lab")

################################################################################

Before do
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

After do |scenario|
  File.open($servers_bin, 'w') do |f|
    f.puts(Marshal.dump($drb_test_lab.servers))
  end

  Kernel.exit if scenario.failed?

  # cleanup non-persistent lxc containers between tests
  $drb_test_lab.servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    $drb_test_lab.server_destroy(name)
  end

end

################################################################################

Kernel.at_exit do
  $drb_test_lab.shutdown
end

################################################################################
