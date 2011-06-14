Feature: Installation
  So that I can run cucumber-chef to test my Chef recipes
  As a user
  I can install the gem

  Scenario: Installing the gem
    When I build the gem
    And I install the latest gem
    Then I should have cucumber-chef on my path
    And I can get help about the cucumber-chef binary on the command line
