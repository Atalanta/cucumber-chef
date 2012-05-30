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

Before
  list_containers.each do |container|
    destroy_container(container)
  end

  set_chef_client(:orgname => "cucumber-chef")
end

After do |scenario|
  list_containers.each do |container|
    destroy_container(container)
  end
end
