require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:"cucumber-chef") do |t|
  feature_dirs = Array.new

  feature_dir_glob = File.join(Dir.pwd, "*cookbook*", "*", "*feature*")
  feature_dirs << Dir.glob(feature_dir_glob)

  feature_dir_glob = File.join(Dir.pwd, "*feature*")
  feature_dirs << Dir.glob(feature_dir_glob)

  opts = [
    "--exclude support/cookbooks",
    "--exclude support/data_bags",
    "--exclude support/environments",
    "--exclude support/keys",
    "--exclude support/roles",
    feature_dirs
  ].flatten.compact.join(" ")

  t.cucumber_opts = opts
end
