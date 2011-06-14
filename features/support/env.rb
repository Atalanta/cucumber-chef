#!/usr/bin/env ruby

$: << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
$: << File.expand_path(File.dirname(__FILE__))

require 'rspec/expectations'
require 'chef'
require 'cucumber/chef'
require 'cucumber/nagios/steps'

class CustomWorld
  include Cucumber::Chef
end

World do
  CustomWorld.new
end

Around('@invalid_credentials') do |scenario, block|
  FileUtils.mkdir_p(".chef")
  config = "chef_node_name 'REALLYBOGUSORGNAME'"
  File.open(".chef/knife.rb", 'w') { |f| f.puts config }
  block.call
  FileUtils.rm_rf(".chef")
end
