name "controller"
description "Cucumber-chef controller node for running tests."
run_list(
  "recipe[cucumber-chef::test_runner]"
)

override_attributes "cucumber-chef" => {
  "orgname" => "#{ENV['ORGNAME']}"
}