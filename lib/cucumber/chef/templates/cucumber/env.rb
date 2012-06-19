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

  # cleanup previous lxc containers on first run
  if (ENV['DESTROY'] == "1")
    STDOUT.puts("\033[34m  >>> \033[1mservers\033[0m\033[34m are being destroyed\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)

    servers.each do |name|
      server_destroy(name)
    end
    File.delete($servers_bin)
  else
    STDOUT.puts("\033[34m  >>> \033[1mservers\033[0m\033[34m are being preserved\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)
  end

  $servers = Marshal.load(IO.read($servers_bin)) if (!defined?($servers) && File.exists?($servers_bin))

  # for Opscode Hosted chef-server use this:
  #chef_set_client_config(:orgname => "cucumber-chef")

  # for Opscode OS chef-server on the Cucumber-Chef test lab use this:
  chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                         :validation_client_name => "chef-validator")
end

After do |scenario|
  data = Marshal.dump($servers)
  File.open($servers_bin, 'w') do |f|
    f.puts(Marshal.dump($servers))
  end
  exit(255) if scenario.failed?

  # cleanup non-persistent lxc containers on exit
  $servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    server_destroy(name)
  end
end
