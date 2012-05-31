require 'rspec/expectations'
require 'chef'
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

Before do
  @servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    destroy_server(name)
  end

  set_chef_client(:orgname => "cucumber-chef")
end

After do |scenario|
  @servers.select{ |name, attributes| !attributes[:persist] }.each do |name, attributes|
    destroy_server(name)
  end
end
