require "rubygems"
require "bundler/setup"
require File.join(File.dirname(__FILE__), "../lib/cucumber-chef")
require "simplecov"

SimpleCov.start do
  add_filter '/spec/'

#  add_group 'cucumber-chef', '/lib/'
end if ENV["COVERAGE"]

def tcp_test_ssh(hostname)
  tcp_socket = TCPSocket.new(hostname, 22)
  IO.select([tcp_socket], nil, nil, 5)
rescue Errno::ETIMEDOUT
  false
rescue Errno::EPERM
  false
rescue Errno::ECONNREFUSED
  sleep 2
  false
  # This happens on EC2 quite often
rescue Errno::EHOSTUNREACH
  sleep 2
  false
ensure
  tcp_socket && tcp_socket.close
end

%w{ORGNAME OPSCODE_USER}.each do |var|
  if ENV[var].nil? || ENV[var].empty?
    warn "Specs require the environment variables $ORGNAME and $OPSCODE_USER to be set."
    exit 1
  end
end
