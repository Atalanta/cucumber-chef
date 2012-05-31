require File.expand_path(File.join(File.dirname(__FILE__), "..", "lib", "cucumber-chef"))

SimpleCov.start do
  add_filter '/spec/'
#  add_group 'cucumber-chef', '/lib/'
end if ENV["COVERAGE"]
