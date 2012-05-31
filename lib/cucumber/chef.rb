require 'readline'
require 'socket'
require 'stringio'

require 'fog'
require 'json'
require 'mixlib/config'
require 'net/ssh'
require 'net/ssh/proxy/command'
require 'net/sftp'
require 'ubuntu_ami'

module Cucumber
  module Chef

    class Error < StandardError; end

    autoload :Command, 'cucumber/chef/command'
    autoload :Config, 'cucumber/chef/config'
    autoload :Bootstrap, 'cucumber/chef/bootstrap'
    autoload :Provisioner, 'cucumber/chef/provisioner'
    autoload :SSH, 'cucumber/chef/ssh'
    autoload :Template, 'cucumber/chef/template'
    autoload :TestLab, 'cucumber/chef/test_lab'
    autoload :TestRunner, 'cucumber/chef/test_runner'

  end
end

begin
rescue LoadError => e
  dep = e.message.split.last
  puts "You don't appear to have #{dep} installed."
  puts "Perhaps run `gem bundle` or `gem install #{dep}`?"
  exit 2
end
