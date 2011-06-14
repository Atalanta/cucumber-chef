name "controller"
description "Cucumber-chef controller node for running tests."
run_list(
	 "recipe[cucumber-chef::testrunner]"
)

override_attributes "cucumber-chef" => { "orgname" => "#{ENV['ORGNAME']}" }
