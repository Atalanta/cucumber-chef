require 'cucumber-chef'

SimpleCov.start do
  add_filter '/spec/'
#  add_group 'cucumber-chef', '/lib/'
end if ENV["COVERAGE"]
