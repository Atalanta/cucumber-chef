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

  Scenario: The user has been added
    When I run "cat /etc/passwd | grep [b]dobbs"
      Then I should see "bdobbs" in the output
      And I should see "/home/bdobbs" in the output
      And I should see "/bin/bash" in the output

  Scenario: The user's groups have been added
    When I run "cat /etc/group | grep [b]dobbs"
      Then I should see "bdobbs" in the output
      And I should see "sysop" in the output
      And I should see "dba" in the output
      And I should see "dev" in the output

  Scenario: The user's ssh keys have been populated
    When I run "cat /home/bdobbs/.ssh/authorized_keys"
      Then I should see "ssh-rsa" in the output
      And I should see "bob@dobbs" in the output

  Scenario: The user's ssh config has been populated
    When I run "cat /home/bdobbs/.ssh/config"
      Then I should see "KeepAlive yes" in the output
      And I should see "ServerAliveInterval 60" in the output

  Scenario: The user can ssh in to the system with their key pair
    * I ssh to "users" with the following credentials:
      | username | keyfile |
      | bdobbs | ./support/keys/bdobbs |
    When I run "hostname"
    Then I should see "users" in the output
