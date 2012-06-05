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

  # cleanup previous lxc containers on first run
  if ($servers.size == 0)
    STDOUT.puts("\033[34m    * \033[1mall\033[0m\033[34m servers are being destroyed\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)

    servers.each do |name|
      server_destroy(name)
    end
  end

  # for Opscode Hosted chef-server use this:
  #chef_set_client_config(:orgname => "cucumber-chef")

  # for Opscode OS chef-server on the Cucumber-Chef test lab use this:
  chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                         :validation_client_name => "chef-validator")
end

After do |scenario|
  Kernel.exit if scenario.failed?

  # cleanup non-persistent lxc containers on exit
  $servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    server_destroy(name)
  end
end
