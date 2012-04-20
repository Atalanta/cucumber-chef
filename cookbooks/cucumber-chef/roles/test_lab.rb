name "test_lab"
description "Platform for running acceptance and integration tests"
run_list(
  "recipe[cucumber-chef::lxc]",
  "recipe[cucumber-chef::test_lab]",
  "recipe[cucumber-chef::controller]"
)

# "gems" => %w(cucumber-chef rspec cucumber)
override_attributes "cucumber-chef" => {
  "orgname" => "#{ENV['ORGNAME']}",
  "gems" => [
    { :name => 'rspec' },
    { :name => 'cucumber' },
    { :name => 'cucumber-nagios' },
    { :name => 'cucumber-chef' }
  ]
}