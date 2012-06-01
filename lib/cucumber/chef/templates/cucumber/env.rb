require 'rspec/expectations'
#require 'chef'
require 'cucumber/chef'
require 'cucumber/chef/steps'
require 'cucumber/chef/helpers'

class CustomWorld
  include Cucumber::Chef
  include Cucumber::Chef::Helpers
end

World do
  CustomWorld.new
end

$servers = Hash.new(nil)

Before do
  # cleanup previous lxc containers on first run
  if ($servers.size == 0)
    STDOUT.puts("$servers.size == 0")
    STDOUT.flush if STDOUT.respond_to?(:flush)

    list_containers.each do |container|
      destroy_container(container)
    end
  end

  # destroy any non-persistent containers before we start this scenario
  $servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    destroy_server(name)
  end

  # for Opscode Hosted chef-server use this:
  #set_chef_client(:orgname => "cucumber-chef")

  # for Opscode OS chef-server on the Cucumber-Chef test lab use this:
  set_chef_client(:chef_server_url => "http://192.168.255.254:4000",
                  :validation_client_name => "chef-validator")
end

# cleanup non-persistent lxc containers on exit
Kernel.at_exit do
  $servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    destroy_server(name)
  end
end
