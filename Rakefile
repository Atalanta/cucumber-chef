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
