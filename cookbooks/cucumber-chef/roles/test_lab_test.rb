name "test_lab_test"
description "Platform for running acceptance and integration tests"
run_list(
	 "recipe[cucumber-chef::lxc]",
	 "recipe[cucumber-chef::test_lab]",
	 "recipe[cucumber-chef::controller]"
)

override_attributes "cucumber-chef" => { "orgname" => "#{ENV['ORGNAME']}" }
