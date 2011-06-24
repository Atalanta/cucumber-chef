require 'yaml'
require 'rubygems'
require 'fog'

Given /^I have an Opscode Platform account$/ do
  silent_system("cucumber-chef genconfig")
  file_should_exist( "~/.cucumber-chef-sample" )
  config = YAML::load( File.open( File.expand_path('~/.cucumber-chef-sample') ) )
  username = config['chef_node_name']
  req = Net::HTTP.new('community.opscode.com', 80)
  req.request_head("/users/#{username}").code.should == "200"
end

Given /^an EC2 account$/ do
  config = YAML::load( File.open( File.expand_path('~/.cucumber-chef-sample') ) )
  access_key = config["aws_access_key"]
  secret_key = config["aws_secret_key"]
  compute = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key, :aws_secret_access_key => secret_key)
  compute.describe_availability_zones.should_not be_nil
end

Given /^I have chef installed on my machine$/ do
  silent_system("which chef-client").should be_true
end

When /^I run cucumber\-chef setup$/ do
  @output = %x[cucumber-chef setup --config=#{File.expand_path('~/.cucumber-chef-sample')}]
end

Then /^I should be told the instance id and IP address$/ do
  @output.should match(/i-[0-9a-f]{8}/)
  @instance_ip_address = @output[/IP Address ([\d|\.]+)/, 1]
end
