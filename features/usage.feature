Feature: Usage of cucumber-chef command line tool
  So that I can make use of cucumber-chef functionality
  As a user
  I can do really vague shit

Scenario: Show config
  Given that cucumber-chef is installed
  When I display the config
  Then I should see config settings from knife.rb
  
@invalid_credentials
Scenario: Warn on bad credentials
  Given that cucumber-chef is installed
  But the config file contains invalid credentials
  When I run a cucumber-chef subcommand requiring Opscode and AWS credentials
  Then I should be alerted that my credentials are invalid

Scenario: Create a project
  Given that cucumber-chef is installed
  When I create a project called test_project
  Then a new directory will be created named test_project
  And it will contain directories for features, step_definitions, and support
  And the support directory will contain essential libraries and helper imports 
  And examples and documentation will be included


