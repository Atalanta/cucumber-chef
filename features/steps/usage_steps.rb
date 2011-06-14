Given /^that cucumber\-chef is installed$/ do
  When 'I build the gem'
  And 'I install the latest gem'
  Then 'I should have cucumber-chef on my path'
end

When /^I display the config$/ do
  @output = %x[cucumber-chef displayconfig 2>&1]
end

Then /^I should see config settings from knife\.rb$/ do
  @output.should match /^chef_server_url: https:\/\/api.opscode.com\/organization/im
end

When /^I run a cucumber\-chef subcommand requiring Opscode and AWS credentials$/ do
  @output = %x[cucumber-chef setup 2>&1]
end

When /^the config file contains invalid credentials$/ do
  # see support/env.rb Around block
  true
end

Then /^I should be alerted that my credentials are invalid$/ do
  @output.should match(/Invalid Opscode platform credentials. Please check/m)
end

When /^I create a project called test_project$/ do
  @project_name = "test_project"
  project = "/tmp/cucumber-chef/#{@project_name}"
  if File.exist?(project)
    FileUtils.rm_rf(project)
  end
  silent_system("cd /tmp ; cucumber-chef project #{@project_name}").should be_true
end

project_dir = '/tmp/cucumber-chef/test_project'
features_dir = "#{project_dir}/features"

Then /^a new directory will be created named test_project$/ do
  file_should_exist(project_dir)
end

Then /^it will contain directories for features, step_definitions, and support$/ do
  %w[support step_definitions].each { |dir| file_should_exist("#{features_dir}/#{dir}") }
end

Then /^the support directory will contain essential libraries and helper imports$/ do
  file_should_exist( "#{features_dir}/support/env.rb" )
  file_should_contain( "#{features_dir}/support/env.rb",
                       "require 'cucumber/chef'\n" )
end

Then /^examples and documentation will be included$/ do
  file_should_contain("#{project_dir}/README",
                      'Welcome to the test_project suite of cucumber-chef tests')
  file_should_contain("#{features_dir}/example.feature",
                      'Feature: Example feature for test_project')
  file_should_contain("#{features_dir}/step_definitions/example_step.rb",
                      'Given /^I apply the test_project role\/recipe$/ do')
end

