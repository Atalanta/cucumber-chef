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
