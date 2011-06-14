require "rubygems"
require "bundler/setup"
require File.join(File.dirname(__FILE__), "../../lib/cucumber-chef")

describe Cucumber::Chef::TestRunner do
  before(:all) do
    @config = Cucumber::Chef::Config.test_config
  end
end

