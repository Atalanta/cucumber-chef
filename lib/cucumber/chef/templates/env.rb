#!/usr/bin/env ruby

require 'rspec/expectations'
require 'chef'
require 'cucumber/chef'
require 'cucumber/nagios/steps'
require 'cucumber/chef/handy'

class CustomWorld
  include Cucumber::Chef
  include Cucumber::Chef::Handy
end

World do
  CustomWorld.new
end
