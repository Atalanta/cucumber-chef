require 'rspec/expectations'
require 'cucumber/chef'
require 'cucumber/chef/helpers'
require 'cucumber/chef/steps'
require 'cucumber/chef/version'

class CustomWorld
  include Cucumber::Chef
  include Cucumber::Chef::Helpers
end

World do
  CustomWorld.new
end

$servers = Hash.new(nil)

Before do
  knife_rb = Cucumber::Chef.locate(:file, ".chef", "knife.rb")
  Chef::Config.from_file(knife_rb)

  $servers_bin ||= (Cucumber::Chef.locate(:file, ENV['HOME'], "servers.bin") rescue File.expand_path(File.join(ENV['HOME'], "servers.bin")))

  # cleanup previous lxc containers if asked
  if (ENV['DESTROY'] == "1")
    log("servers", "are being destroyed")
    servers.each do |name|
      server_destroy(name)
    end
    File.exists?($servers_bin) && File.delete($servers_bin)
  else
    log("servers", "are being preserved")
  end

  if File.exists?($servers_bin)
    $servers = Marshal.load(IO.read($servers_bin))
  end

  chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                         :validation_client_name => "chef-validator")
end

After do |scenario|
  @connection.close if @connection

  File.open($servers_bin, 'w') do |f|
    f.puts(Marshal.dump($servers))
  end

  Kernel.exit if scenario.failed?

  # cleanup non-persistent lxc containers on exit
  $servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    server_destroy(name)
  end
end
