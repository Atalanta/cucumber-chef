################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systemspec.com>
#      Author: Zachary Patten <zachary@jovelabspec.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cucumber/chef/version'

Gem::Specification.new do |spec|
  spec.name          = "cucumber-chef"
  spec.version       = Cucumber::Chef::VERSION
  spec.authors       = ["Stephen Nelson-Smith", "Zachary Patten"]
  spec.email         = ["stephen@atalanta-systemspec.com", "zachary@jovelabspec.com"]
  spec.description   = "Framework for test-driven infrastructure development."
  spec.summary       = "Test Driven Infrastructure"
  spec.homepage      = "http://www.cucumber-chef.org"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # Providers
  spec.add_dependency("fog", ">= 1.3.1")

  # TDD
  spec.add_dependency("cucumber")
  spec.add_dependency("rspec")

  # Support
  spec.add_dependency("mixlib-config", ">= 1.1.2")
  spec.add_dependency("rake", ">= 0.9.2")
  spec.add_dependency("thor", ">= 0.15.2")
  spec.add_dependency("ubuntu_ami", ">= 0.4.0")
  spec.add_dependency("ztk", ">= 1.0.9")

  spec.add_development_dependency("simplecov")
  spec.add_development_dependency("pry")
  spec.add_development_dependency("yard")
  spec.add_development_dependency("redcarpet")
end
