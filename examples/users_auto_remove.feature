@users
Feature: Perform test driven infrastructure with Cucumber-Chef
  In order to learn how to develop test driven infrastructure
  As an infrastructure developer
  I want to better understand how to use Cucumber-Chef

  Background:
    * I have a server called "users"
    * "users" is running "ubuntu" "lucid"
    * "users" has been provisioned
    * the following roles have been updated:
      | role | role_path |
      | users | ./support/roles/ |
    * the "users" role has been added to the "users" run list
    * the following databags have been updated:
      | databag | databag_path |
      | users | ./support/data_bags/users |
    * the chef-client has been run on "users"
    * I ssh to "users" with the following credentials:
      | username | keyfile |
      | root | ../.ssh/id_rsa |

  Scenario: The user has been removed
    * the following databags have been updated:
      | databag | databag_path |
      | users | ./support/data_bags/users-auto-remove |
    * the chef-client has been run on "users"
    When I run "cat /etc/passwd | grep [b]dobbs"
      Then I should not see "bdobbs" in the output
      And I should not see "/home/bdobbs" in the output
      And I should not see "/bin/bash" in the output

  Scenario: The user's group has been removed
    * the following databags have been updated:
      | databag | databag_path |
      | users | ./support/data_bags/users-auto-remove |
    * the chef-client has been run on "users"
    When I run "cat /etc/group | grep [b]dobbs"
      Then I should not see "bdobbs" in the output
      And I should not see "sysop" in the output
      And I should not see "dba" in the output
      And I should not see "dev" in the output

  Scenario: The user's directory has been preserved on remove
    * the following databags have been updated:
      | databag | databag_path |
      | users | ./support/data_bags/users-auto-remove |
    * the chef-client has been run on "users"
    When I run "[[ -e /home/bdobbs ]] && echo OK"
      Then I should see "OK" in the output
