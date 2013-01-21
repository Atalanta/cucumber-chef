################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
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

require 'bundler/gem_tasks'

################################################################################

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec
task :test => :spec

################################################################################

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:cucumber)

################################################################################

desc "Run RSpec with code coverage"
task :coverage do
  `rake spec COVERAGE=true`
  case RUBY_PLATFORM
  when /darwin/
    `open coverage/index.html`
  when /linux/
    `google-chrome coverage/index.html`
  end
end

################################################################################
