#!/usr/bin/env ruby

require 'rspec/expectations'
require 'chef'
require 'cucumber/chef'
require 'cucumber/chef/steps'
require 'cucumber/chef/handy'

class CustomWorld
  include Cucumber::Chef
  include Cucumber::Chef::Handy
end

World do
  CustomWorld.new
end

# if our scenario passed destroy the containers, otherwise quit so we can inspect the containers if desired.
After do |scenario|
  if scenario.passed?
    list_containers.each do |container|
      destroy_container(container)
    end
  else
    Cucumber.wants_to_quit = true
  end
end
