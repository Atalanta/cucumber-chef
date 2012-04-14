# encoding: utf-8

require File.expand_path("../lib/cucumber/chef/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "cucumber-chef"
  s.version = Cucumber::Chef::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Zachary Patten", "Stephen Nelson-Smith"]
  s.email = ["jovelabs@gmail.com", "stephen@atalanta-systems.com"]
  s.homepage = "http://github.com/zpatten/cucumber-chef"
  s.description = "Framework for behaviour-drive infrastructure development."
  s.summary = "Tests Chef-built infrastructure"
  s.required_rubygems_version = ">= 1.3.6"
  s.licenses = ["Apache v2"]

  s.add_dependency "chef"
  s.add_dependency "cucumber"
  s.add_dependency "cucumber-nagios"
  s.add_dependency "fog"
  s.add_dependency "thor"
  s.add_dependency "net-scp"
  s.add_dependency "ubuntu_ami"

  s.add_development_dependency "bundler", "~> 1.0.0"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rdoc"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end