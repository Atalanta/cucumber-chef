require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:"cucumber-chef") do |t|
  opts = [
    "--exclude support/cookbooks",
    "--exclude support/data_bags",
    "--exclude support/roles",
    "--exclude support/environments"
  ]

  t.cucumber_opts = opts.join(" ")
end
