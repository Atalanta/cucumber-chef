# -*- encoding: utf-8 -*-

require File.expand_path("../lib/cucumber/chef/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "cucumber-chef"
  s.version = Cucumber::Chef::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Stephen Nelson-Smith", "Zachary Patten"]
  s.email = ["stephen@atalanta-systems.com", "zpatten@jovelabs.com"]
  s.homepage = "http://www.cucumber-chef.org"
  s.summary = "Tests Chef-built infrastructure"
  s.description = "Framework for behaviour-drive infrastructure development."
  s.required_rubygems_version = ">= 1.3.6"
  s.licenses = ["Apache v2"]

  s.add_dependency "chef", "~> 0.10.8"
  s.add_dependency "fog", ">= 0"
  s.add_dependency "cucumber", ">= 0"
  s.add_dependency "thor", ">= 0"
  s.add_dependency "ubuntu_ami", ">= 0"
  s.add_dependency "rake", "~> 0.9.2"
  s.add_dependency "net-sftp", "~> 2.0.5"

  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov"

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.require_path = 'lib'
end
