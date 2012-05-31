require 'cucumber-chef'

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end if ENV["COVERAGE"]
