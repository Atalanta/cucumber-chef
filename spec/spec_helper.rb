require 'cucumber-chef'

dev_null = File.open("/dev/null", "w")
$logger = Cucumber::Chef::Logger.new(dev_null)

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end if ENV["COVERAGE"]
