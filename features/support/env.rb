#!/usr/bin/env ruby

$: << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
$: << File.expand_path(File.dirname(__FILE__))

require 'rspec/expectations'
require 'cucumber/chef'

class CustomWorld
  include Cucumber::Chef
end

World do
  CustomWorld.new
end

Around('@invalid_credentials') do |scenario, block|
  # Move current working directory if one exists (and restore at end)
  FileUtils.mv(".chef", ".chef_cucumber_temp") if File.exist?(".chef")
  FileUtils.mkdir_p(".chef")
  config = "chef_node_name 'REALLYBOGUSORGNAME'"
  File.open(".chef/knife.rb", 'w') { |f| f.puts config }
  block.call
  FileUtils.rm_rf(".chef")
  FileUtils.mv(".chef_cucumber_temp", ".chef") if File.exist?(".chef_cucumber_temp")
end
