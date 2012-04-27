require 'readline'
require 'socket'
require 'stringio'

require 'chef'
require 'chef/cookbook_uploader'
require 'chef/knife'
require 'chef/knife/bootstrap'
require 'chef/knife/core/bootstrap_context'
require 'chef/knife/ssh'
require 'fog'
#require 'net/scp'
require 'net/ssh/multi'

module Cucumber
  module Chef
    class Error < StandardError ; end

    autoload :Config, "cucumber/chef/config"
    autoload :Provisioner, "cucumber/chef/provisioner"
    autoload :TestLab, "cucumber/chef/test_lab"
    autoload :TestRunner, "cucumber/chef/test_runner"
  end
end

begin
  require 'cucumber/chef/version'
rescue LoadError => e
  dep = e.message.split.last
  puts "You don't appear to have #{dep} installed."
  puts "Perhaps run `gem bundle` or `gem install #{dep}`?"
  exit 2
end
