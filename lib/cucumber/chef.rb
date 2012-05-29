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
require 'net/ssh/multi'
require 'net/ssh/proxy/command'
require 'net/sftp'

module Cucumber
  module Chef
    class Error < StandardError ; end

    autoload :Config, "cucumber/chef/config"
    autoload :Bootstrap, "cucumber/chef/bootstrap"
    autoload :Provisioner, "cucumber/chef/provisioner"
    autoload :SSH, "cucumber/chef/ssh"
    autoload :TestLab, "cucumber/chef/test_lab"
    autoload :TestRunner, "cucumber/chef/test_runner"

  end
end

begin
rescue LoadError => e
  dep = e.message.split.last
  puts "You don't appear to have #{dep} installed."
  puts "Perhaps run `gem bundle` or `gem install #{dep}`?"
  exit 2
end
