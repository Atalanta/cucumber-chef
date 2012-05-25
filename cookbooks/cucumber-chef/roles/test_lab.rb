name "test_lab"
description "Platform for running acceptance and integration tests"
run_list(
  "recipe[cucumber-chef::lxc]",
  "recipe[cucumber-chef::test_lab]"
)

override_attributes "cucumber-chef" => {
  "orgname" => "#{ENV["ORGNAME"]}",
  "nodename" => "cucumber-chef-controller"
}
