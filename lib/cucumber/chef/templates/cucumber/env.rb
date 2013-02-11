require 'rspec/expectations'
require 'cucumber/chef'
require 'cucumber/chef/steps'

class CustomWorld
  include Cucumber::Chef
end

World do
  CustomWorld.new
end
