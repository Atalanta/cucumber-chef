name "test_lab_test"
description "Platform for running acceptance and integration tests"
run_list(
   "recipe[cucumber-chef::lxc]",
   "recipe[cucumber-chef::test_lab]",
   "recipe[cucumber-chef::controller]"
)

# "gems" => %w(cucumber-chef rspec cucumber)
override_attributes "cucumber-chef" => {
  "orgname" => "#{ENV['ORGNAME']}",
  "gems" => %w(rspec cucumber cucumber-nagios cucumber-chef)
}