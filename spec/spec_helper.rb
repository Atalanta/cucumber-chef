require File.join(File.dirname(__FILE__), "../lib/cucumber-chef")

SimpleCov.start do
  add_filter '/spec/'
#  add_group 'cucumber-chef', '/lib/'
end if ENV["COVERAGE"]

%w{ORGNAME OPSCODE_USER}.each do |var|
  if ENV[var].nil? || ENV[var].empty?
    warn "Specs require the environment variables $ORGNAME and $OPSCODE_USER to be set."
    exit 1
  end
end
