################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

require File.expand_path("../lib/cucumber/chef/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "cucumber-chef"
  s.version = Cucumber::Chef::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Stephen Nelson-Smith", "Zachary Patten"]
  s.email = ["stephen@atalanta-systems.com", "zachary@jovelabs.com"]
  s.homepage = "http://www.cucumber-chef.org"
  s.summary = "Test Driven Infrastructure"
  s.description = "Framework for test-driven infrastructure development."
  s.required_ruby_version = ">= 1.8.7"
  s.required_rubygems_version = ">= 1.3.6"
  s.licenses = ["Apache 2.0"]

  s.add_dependency("chef", ">= 0.10.10")
  s.add_dependency("cucumber", ">= 1.2.0")
  s.add_dependency("fog", ">= 1.3.1")
  s.add_dependency("mixlib-config", ">= 1.1.2")
  s.add_dependency("thor", ">= 0.15.2")
  s.add_dependency("rake", ">= 0.9.2")
  s.add_dependency("ubuntu_ami", ">= 0.4.0")
  s.add_dependency("rspec", ">= 2.10.0")
  s.add_dependency("ztk", ">= 0.0.15")

  s.add_development_dependency("simplecov", ">= 0.6.4")
  s.add_development_dependency("pry", ">= 0")
  s.add_development_dependency("yard", ">= 0")
  s.add_development_dependency("redcarpet", ">= 0")

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.require_path = 'lib'
end
