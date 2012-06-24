[![Build Status](https://secure.travis-ci.org/zpatten/cucumber-chef.png)](http://travis-ci.org/zpatten/cucumber-chef)

Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which Cucumber tests can be run which provision virtual machines, configure them by applying the appropriate Chef roles to them, and then run acceptance and integration tests against the environment.

## Overview

Cucumber-chef begins with a very simple premise.  If we are framing our infrastructure as code - if we're writing cookbooks, recipes and other pieces of automation in a high level programming language, such as Ruby, then it makes sense to follow the current wisdom across the software development world to maximise the quality, maintainability and reusability of our code, providing maximum chance that we'll deliver value with it.  One area which has been shown to have a very positive effect is the practive of 'test-driven' development.  In this paradigm, the developer begins by writing a test that captures the intended behaviour of the code they are going to write.  This test will start out by failing.  The developer then writes code to make the test pass, and iterates thereafter.

Cucumber-chef provides a framework to make it easier to do test-driven development for infrastructure.  It does this by providing a test infrastructure, which we call the "test lab", within which a number of different scenarios can be set up, and against which Cucumber features can we run.  From the outset, Cucumber-chef's design was to provide a fast, lightweight and cheap way to fire up virtual machines for testing.  At present this is achieved using Linux Containers on Amazon EC2.  Supporting alternative provisioning backends is planned, which will allow the user to opt to test using local machines, alternative cloud providers, and ultimatey alternative virtualization technologies.

For node convergence, Cucumber-Chef uses the open-source Chef server.  It can be configured to use Hosted Chef or Private Chef.  Supoprt for Chef-solo will be included in a future relase.

As you might have guessed from the name, we're going to write high level acceptance tests using Cucumber.  Cucumber-Chef provides step definitions and helper methods to make it easy to provision and manage machines with Chef, and then build end-to-end tests.

## Getting Started

*LISTEN UP*

Here's the headline:

With a /single command/ Cucumber-Chef will provision a machine, set up an open source Chef server, bootstrap it to support the creation of Linux containers, set up an environment from which to run tests, and automatically configure your system to use it.

This means getting started with Cucumber-Chef is a simple, two step process.

1. Install Cucumber-Chef

2. Run `cucumber-chef init` to configure Cucumber-Chef.

3. Run `cucumber-chef setup` to build your test lab.

### Installing Cucumber-Chef

Cucumber-Chef is distributed as a RubyGem.  To install it you have two options - stable or development.

#### Installing the stable version

Simply install from RubyGems:

    $ gem install cucumber-chef

Depending on your local setup (ie whether you're using RVM or rbenv, or distribution-provided Ruby), you may need to run this with superuser privileges.

#### Installing the development version

If you want to try a development version, simply clone this repo, and build the gem yourself:

    $ git clone git://github.com/Atalanta/cucumber-chef -b BRANCH
    $ cd cucumber-chef
    $ bundle
    $ rake build
    $ gem install pkg/cucumber-chef-VERSION.gem

Again, depending on your local setup (ie whether you're using RVM or rbenv, or distribution-provided Ruby), you may need to run parts of this process with superuser privileges.

### Running `cucumber-chef init`

Cucumber-Chef ships with an initialization task, which will interactively generate configuration file.  This requires you to have, and know your Amazon Web Services credntials.  On completion of the interactive configuration, it will provision a machine on EC2, and set up the entire infrastructure, using Chef.

Cucumber-Chef doesn't demand where you keep your configuration file.  By default, the config will be created in `~/.cucumber-chef`, but this can be overridden.  Cucumber-Chef is clever enough to find your config, so it's all cool.

The two obvious places to keep this config, are in the top level of your Chef repository, or in a dedicated Cucumber-Chef repository, but you're free to do whatever works for you.

You can view and verify the current config at any time by running `cucumber-chef displayconfig`.  If Cucumber-Chef thinks your config is incorrect, or incomplete, it'll tell you.

## Using Cucumber-Chef

Once installed, you can run `cucumber-chef` on the command line to get an overview of the tasks it can carry out.

    $ cucumber-chef
    Tasks:
      cucumber-chef create <project>         # Create a project template for testing an infrastructure.
      cucumber-chef diagnose <container>     # Provide diagnostics from the chef-client on the specified container.
      cucumber-chef displayconfig            # Display the current cucumber-chef config.
      cucumber-chef down                     # Shutdown the cucumber-chef test lab
      cucumber-chef help [TASK]              # Describe available tasks or one specific task
      cucumber-chef info                     # Display information about the current test lab.
      cucumber-chef init                     # Initalize cucumber-chef configuration
      cucumber-chef ps [ps-options]          # Snapshot of the current cucumber-chef test lab container processes.
      cucumber-chef setup                    # Setup cucumber-chef test lab in Amazon EC2
      cucumber-chef ssh [container]          # SSH to cucumber-chef test lab or [container] if specified.
      cucumber-chef teardown                 # Teardown cucumber-chef test lab in Amazon EC2
      cucumber-chef test [cucumber-options]  # Test a project using the cucumber-chef test suite.
      cucumber-chef up                       # Startup the cucumber-chef test lab

After tunning set up, which takes about 15 minutes, you'll have a fully funtioning platform available for you to use.  Let's just quickly review what that means.  You will have an EC2 machine, fully managed by Chef, and providing the following:

* The ability to provision LXC containers
* The ability to run tests against LXC containers
* A dedicated environment for certain kinds of testing scenarios

The next stage is to set up a project.  A project is simply a directory structure for containing your cucumber features and steps, already set up with an appropriate environment to make use of the step definitions provided with Cucumber-Chef.  Cucumber-chef provides a task which will create a the directory for you, and populate it with a README and an example feature and steps.  These represent futher documentation, and provide a model and steps to get you up and running with your testing as quickly as possible.

    $ cd /path/to/chef-repo
    $ cucumber-chef create myproject

This will create a directory, cucumber-chef, and a subdirectory, `myproject`.

    └── myproject
        ├── README
        └── features
            ├── myproject.feature
            ├── step_definitions
            │   └── myproject_steps.rb
            └── support
                └── env.rb

### General Tasks

#### `up`

If you are using an EBS volume, you can start and stop your test lab.  This task will attempt to start your Cucumber-Chef test lab if it is currently stopped.

#### `down`

If you are using an EBS volume, you can start and stop your test lab.  This task will attempt to stop your Cucumber-Chef test lab if it is currently running.

## Writing Tests

Once you've got your test lab set up, and you've generated a project, it's time to crack on with writing a test.  The basic idea is this:

1. An infrastructure requirement is established
2. Write a cucumber feature that expresses the required behaviour of the infrastructure requirement
3. Write steps that will build this infrastructure environment on the test lab, using the step definitions provided - these include the ability to create a container, apply roles to it, and destroy it again.
4. Write cookbooks and recipes and supporting code to make the test pass

### Container Details

All containers operate off a bridged interface on the test-lab.  All outbound, non-local traffic from the LXC containers are NAT'd through the test-lab and off to the outside world.  This bridged interface on the test-lab is configured as follows:

    CIDR: 192.168.0.0/16
    IP Address: 192.168.255.254
    Netmask: 255.255.255.0
    Broadcast: 192.168.255.255

You are free to use any IP in this /24, with the exception of the test-lab itself, which is at `192.168.255.254`.

### Built In Test Steps

#### Provisioning

We provide several built in steps to help you with provisioning.  It is suggested you build a `Background` section for your features so these are not repeated with each scenario.  This example `Background` section does the following:

* Sets up a server called `devopserver`.
* Makes the server persistant (it will remain up after the test finishes, which is the default behaviour).
* Assigns what linux distro and release to use for the container.
* Assigns it an IP address on the test lab network (this can be omitted for an auto-assigned IP).
* Tells Cucumber-Chef to provision the server.
* Adds the `chef-client::service` recipe in to the chef-client's run list.
* Executes `chef-client` with the generated run list.
* Starts an SSH session to the server so you can execute commands and test the output of those commands in the scenarios.

Here is the `Background` section as you might write it in a feature:

      Background:
        * I have a server called "devopserver"
        * "devopserver" should be persistant
        * "devopserver" is running "ubuntu" "lucid"
        * "devopserver" has an IP address of "192.168.73.31"
        * "devopserver" has been provisioned
        * the "chef-client::service" recipe has been added to the "devopserver" run list
        * the chef-client has been run on "devopserver"
        * I ssh to "devopserver" with the following credentials:
          | username | password |
          | root     | root     |

To get a persistent server with an auto-assigned IP address using the generated and populated test lab SSH key pairs for SSH authentication you could write something like this.  Remember the tests run on the test lab, so we can just back out a directory and reference our test lab SSH private key directly:

      Background:
        * I have a server called "devopserver"
        * "devopserver" is running "ubuntu" "lucid"
        * "devopserver" has been provisioned
        * the "chef-client::service" recipe has been added to the "devopserver" run list
        * the chef-client has been run on "devopserver"
        * I ssh to "devopserver" with the following credentials:
          | username | keyfile        |
          | root     | ../.ssh/id_rsa |

You can add roles to the run list by writing:

        * the "chef-client" role has been added to the "devopserver" run list

Here's an example `Scenario` section you might have to test if the chef-client is actually running as a daemon:

      Scenario: Chef-Client is running as a daemon
        When I run "ps aux | grep [c]hef-client"
          Then I should see "chef-client" in the output
          And I should see "-d" in the output
          And I should see "-i 1800" in the output
          And I should see "-s 20" in the output

See the section below label *Example Test Run* for more examples.

##### List of Provisioning Steps

Create a server profile:

    I have a server called "(server)"

Set a (server) to persist or not:

    "(server)" should( not) be persistant

Set (server) to run linux of type (distro), using (release).

    "(server)" is running "(distro)" "(release)"

Supported (distro -> releases):

    ubuntu -> lucid, maverick, natty, oneiric, precise
    fedora -> (release number)

    Fedora releases 12, 13, 14 tested OK.

Assign (server) a specific IP address (must be on the test lab network segment):

    "(server)" has an IP address of "(ip)"

Assign (server) a specific MAC address:

    "(server)" has a MAC address of "(mac)"

Initiate the provision of a (server).  All attributes of the server need to be set before this:

    "(server)" has been provisioned

Add a role to the chef-client run list:

    the "(role)" role has been added to the "(server)" run list

Add a recipe to the chef-client run list:

    the "(recipe)" recipe has been added to the "(server)" run list

Run the chef-client:

    the chef-client has been run on "(server)"

#### Chef Steps

To prep a server with a role and data bag:

        * the following roles have been updated:
          | role | role_path |
          | users | ./support/roles/ |
        * the "users" role has been added to the "users" run list
        * the following databags have been updated:
          | databag | databag_path |
          | users | ./support/data_bags/users |

##### List of Chef Steps

Update/push roles to the chef-server:

        * the following roles have been updated:
          | role | role_path |
          | users | ./support/roles/ |

Update/push data bags to the chef-server:

        * the following databags have been updated:
          | databag | databag_path |
          | users | ./support/data_bags/users |

#### SSH Steps

Here is how you might setup and initate an SSH session using password authentication to a server named `devopserver`:

        * I have no public keys set
        * I ssh to "devopserver" with the following credentials:
          | username | password |
          | root | root |

Here is how you might setup and initate an SSH session using public key authentication to a server named `users`:

        * I ssh to "users" with the following credentials:
          | username | keyfile |
          | root | ../.ssh/id_rsa |

Since the cukes run on the test lab, we can directly reference the public key pairs already there and populated for us.

Suppose we have a cookbook that creates new users.  After it runs we should be able to SSH in with our public keys.  Let's test this.  First we'll do our setup in the `Background`:

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

And now for the `Scenario`:

      Scenario: The user can ssh in to the system with their key pair
        * I ssh to "users" with the following credentials:
          | username | keyfile |
          | bdobbs | ./support/keys/bdobbs |
        When I run "hostname"
        Then I should see "users" in the output


##### List of SSH Steps

Sets the authentication method to password:

    I have no public keys set

Start an SSH session to the server (server) using password authentication:

    I ssh to "(server)" with the following credentials:
      | username | password |
      | root     | root     |

Start an SSH session to the server (server) using public key authentication:

    I ssh to "(server)" with the following credentials:
      | username | keyfile |
      | root     | id_rsa  |

Executes (command) over the previously established SSH session on the server (server):

    I run "(command)"

Check (command) output for an (expected) or (not-expected) string:

    I should( not) see "(expected)" in the output

Check (command) output for existance of or lack of (server) settings:

    I should( not) see the "(ip|mac)" of "(server)" in the output

#### Minitest

##### List of Minitest Steps

    I enable the running of MiniTest suites for "(server)"

    the tests should run and pass on "(server)"

#### Cucumber Before Hook Centric Helpers

* `chef_set_client_config(config={})`

This method configures the chef-client's `client.rb` file.  Currently you can specify `:orgname`, `:log_level`, `:log_location`, `:chef_server_url` and `:validation_client_name`.  See your `env.rb` file if you need to change this to point it at a Hosted Chef Server or need to modify any of these values.

##### Examples

    # for Opscode Hosted chef-server use this:
    #chef_set_client_config(:orgname => "cucumber-chef")

    # for Opscode OS chef-server on the Cucumber-Chef test lab use this:
    chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                           :validation_client_name => "chef-validator")

## Running Tests

You can write the tests and Chef code wherever you like.  We're assuming you prefer working on your local machine, and checking into version control.  But we don't really care.  When it's time to run tests, Cucumber-Chef provides a task which handles this:

    $ cucumber-chef test

Containers are now persisted by default.  This means faster run times on average but if things get screwy, or you want to test from a clean slate, you can easily reset your containers.  If you pass in either `-z` or `--destroy` all containers will be wiped before the test run starts.

    $ cucumber-chef help test
    Usage:
      cucumber-chef test [cucumber-options]

    Options:
      -z, [--destroy]  # destroy all containers before test run

    Test a project using the cucumber-chef test suite.

You can now pass in options for cucumber or even setup profiles via `cucumber.yml`.  Any command-line options specified after the project name will be passed on to cucumber.  For example:

    $ cucumber-chef test --tags @wip -c -v -b

To take advantage of cucumber profiles, create a `cucumber.yml` configuration file in the root of your chef-repo; just as you would with any other project using cucumber.  In this file you can take full advantage of the Cucumber profiles as definied on their wiki, https://github.com/cucumber/cucumber/wiki/cucumber.yml.

Here is an example default project for `cucumber.yml` which turns on colored output, verbosity and full backtraces for all test runs:

    ---
    default: -c -v -b

Running the test task will upload your current project to the test lab, and run the tests, reporting the results back to the screen. Cucumber-chef also provides an upload task, so you can push the current project to the test lab, and then connect to test lab yourself to run tests in a more granular way.  To do this, you need to know the IP of the test lab.  You can find this out by running:

    $ cucumber-chef info

At present, Cucumber-Chef only allows one test lab per AWS account.  In practice, this has not been a constraint.  LXC is incredibly lightweight, and a large number of containers can be provisioned on even a small EC2 instance.

### When Things Go Oh So Wrong

We have put in a few tasks to help you diagnose any issues you may come across with the test lab, containers or your cookbooks and recipes.  There are two main tasks available to help you with this: `ssh` and `diagnose`.

#### `ssh`

    $ cucumber-chef help ssh
    Usage:
      cucumber-chef ssh [container]

    Options:
      [--test]  # INTERNAL USE ONLY

    SSH to cucumber-chef test lab or [container] if specified.

This command provides you with a rapid way to connect to either your test lab or containers.  Think `vagrant ssh`; we took a queue from their wonderful gem and realized we want our gem to provide the same sort of functionality.  The main difference between our `ssh` task and the way Vagrant's task works is that we generate a fresh ssh key pair whenever a test lab is setup; so you can rest assured no one else has a copy of the credientials.  You also do not have to worry about generating or specifying your own key pair to override a default key pair as is the case with Vagrant if you do not want to use the one shipped with Vagrant.

    $ cucumber-chef ssh
    Attempting SSH connection to cucumber-chef 'test lab'...
          _____                           _                _____ _           __
         / ____|                         | |              / ____| |         / _|
        | |    _   _  ___ _   _ _ __ ___ | |__   ___ _ __| |    | |__   ___| |_
        | |   | | | |/ __| | | | '_ ` _ \| '_ \ / _ \ '__| |    | '_ \ / _ \  _|
        | |___| |_| | (__| |_| | | | | | | |_) |  __/ |  | |____| | | |  __/ |
         \_____\__,_|\___|\__,_|_| |_| |_|_.__/ \___|_|   \_____|_| |_|\___|_|


        Welcome to the Cucumber Chef Test Lab v2.0.0.rc1

    Last login: Mon Jun  4 07:56:40 2012 from [REDACTED]
    ubuntu@cucumber-chef:~$

Keep in mind with Amazon's EC2 the base `ubuntu` user is already in the sudoers file; so you can `sudo su -` without needing the password.

    ubuntu@cucumber-chef:~$ sudo su -
    root@cucumber-chef:~#

You can also specify a container name to SSH directly into that container.  For now you are always logged in as `root` when you SSH to a container.

    $ cucumber-chef ssh devopserver
    Attempting SSH connection to cucumber-chef container 'devopserver'...
          _____                           _                _____ _           __
         / ____|                         | |              / ____| |         / _|
        | |    _   _  ___ _   _ _ __ ___ | |__   ___ _ __| |    | |__   ___| |_
        | |   | | | |/ __| | | | '_ ` _ \| '_ \ / _ \ '__| |    | '_ \ / _ \  _|
        | |___| |_| | (__| |_| | | | | | | |_) |  __/ |  | |____| | | |  __/ |
         \_____\__,_|\___|\__,_|_| |_| |_|_.__/ \___|_|   \_____|_| |_|\___|_|


        Welcome to the Cucumber Chef Test Lab v2.0.0.rc1

        You are now logged in to the LXC 'devopserver'

    root@devopserver:~#

#### `diagnose`

This command provides you with a rapid way to get to the chef-client logs without needing to SSH into a container.  There are a few basic options with this task, let's take a look at them.

    $ cucumber-chef help diagnose
    Usage:
      cucumber-chef diagnose <container>

    Options:
      -n, [--lines=N]  # output the last N lines of the chef-client 'chef.log'
                       # Default: 1
      -s, [--strace]   # output the chef-client 'chef-stacktrace.out'
                       # Default: true
      -l, [--log]      # output the chef-client 'chef.log'
                       # Default: true

    Provide diagnostics from the chef-client on the specified container.

With the default options in effect, this task will output the `chef-stacktrace.out` file along with the last line of the `chef.log` file.  You can of course request as many lines as you desire from the `chef.log` file.  For example to look at the last 1000 lines of only the `chef.log` file you would likely run the task as follows.

    $ cucumber-chef diagnose devopserver --no-strace -n 1000

Maybe you only want to view the `chef-stacktrace.out` file?

    $ cucumber-chef diagnose devopserver --no-log

Maybe you want to run it with the default options in play; you would likely get some output as follows.

    $ cucumber-chef diagnose devopserver
    Attempting to collect diagnostic information on cucumber-chef container 'sysopserver'...
    ----------------------------------------------------------------------------
    chef-stacktrace.out:
    ----------------------------------------------------------------------------
    Generated at 2012-06-04 08:30:20 +0000
    Net::HTTPServerException: 412 "Precondition Failed"
    /opt/opscode/embedded/lib/ruby/1.9.1/net/http.rb:2303:in `error!'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/rest.rb:264:in `block in api_request'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/rest.rb:328:in `retriable_rest_request'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/rest.rb:240:in `api_request'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/rest.rb:139:in `post_rest'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/client.rb:313:in `sync_cookbooks'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/client.rb:194:in `setup_run_context'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/client.rb:162:in `run'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/application/client.rb:254:in `block in run_application'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/application/client.rb:241:in `loop'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/application/client.rb:241:in `run_application'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/lib/chef/application.rb:70:in `run'
    /opt/opscode/embedded/lib/ruby/gems/1.9.1/gems/chef-0.10.10/bin/chef-client:26:in `<top (required)>'
    /usr/bin/chef-client:19:in `load'
    /usr/bin/chef-client:19:in `<main>'
    ----------------------------------------------------------------------------
    chef.log:
    ----------------------------------------------------------------------------
    [Mon, 04 Jun 2012 08:30:20 +0000] FATAL: Net::HTTPServerException: 412 "Precondition Failed"


#### `ps`

This command provides you with a snapshot of all the container processes running on the Cucumber-Chef test lab.  You can pass in `ps` command line options to customize the output as you desire.

    $ cucumber-chef help ps
    Usage:
      cucumber-chef ps [ps-options]

    Snapshot of the current cucumber-chef test lab container processes.

Standard usage using `aux` options:

    $ cucumber-chef ps aux
    cucumber-chef v2.0.0.rc1

    Getting container processes from cucumber-chef test lab...

    ============================================================================
    CONTAINER  USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    sudo       root       375  0.0  0.0   2368   608 ?        S    Jun21   0:00 upstart-udev-bridge --daemon
    sudo       syslog     384  0.0  0.0  27296  1264 ?        Sl   Jun21   0:00 rsyslogd -c4
    sudo       root       396  0.0  0.0   2236   388 ?        S<s  Jun21   0:00 udevd --daemon
    sudo       root       406  0.0  0.0   1840   556 pts/19   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty4
    sudo       root       410  0.0  0.0   1840   560 pts/17   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty2
    sudo       root       412  0.0  0.0   1840   560 pts/18   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty3
    sudo       root       416  0.0  0.0   2428   812 ?        Ss   Jun21   0:00 cron
    sudo       root       453  0.0  0.0   1840   564 pts/16   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty1
    sudo       root       455  0.0  0.0   1840   556 pts/20   Ss+  Jun21   0:00 /sbin/getty -8 38400 /dev/console
    sudo       root       477  0.0  0.0   2288   576 ?        Ss   Jun21   0:00 dhclient3 -e IF_METRIC=100 -pf /var/run/dhclient.eth0.pid -lf /var/lib/dhcp3/dhclient.eth0.leases eth0
    sudo       root       493  0.0  0.1   5600  2132 ?        Ss   Jun21   0:00 /usr/sbin/sshd -D
    users      root     20777  0.0  0.0   2720  1484 ?        Ss   Jun21   0:02 /sbin/init
    users      syslog   20876  0.0  0.0  27296  1172 ?        Sl   Jun21   0:02 rsyslogd -c4
    users      root     20877  0.0  0.0   2368   560 ?        S    Jun21   0:00 upstart-udev-bridge --daemon
    users      root     20883  0.0  0.0   2236   516 ?        S<s  Jun21   0:00 udevd --daemon
    users      root     20914  0.0  0.0   1840   544 pts/4    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty4
    users      root     20918  0.0  0.0   1840   540 pts/2    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty2
    users      root     20921  0.0  0.0   1840   544 pts/3    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty3
    users      root     20925  0.0  0.0   2428   788 ?        Ss   Jun21   0:00 cron
    users      root     20953  0.0  0.0   1840   544 pts/1    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty1
    users      root     20954  0.0  0.0   1840   544 pts/5    Ss+  Jun21   0:00 /sbin/getty -8 38400 /dev/console
    users      root     20970  0.0  0.0   2288   572 ?        Ss   Jun21   0:00 dhclient3 -e IF_METRIC=100 -pf /var/run/dhclient.eth0.pid -lf /var/lib/dhcp3/dhclient.eth0.leases eth0
    users      root     20987  0.0  0.1   5600  2128 ?        Ss   Jun21   0:01 /usr/sbin/sshd -D
    users      root     21308  0.0  0.0   1848   488 ?        S    Jun21   0:07 tail -n 250 -f client.log
    users      root     21519  0.0  0.0   1848   484 ?        S    02:19   0:02 tail -n 250 -f /var/log/auth.log
    users      root     21851  0.0  0.0   1848   484 ?        S    02:20   0:02 tail -n 250 -f /var/log/chef/client.log
    chef-client root     27226  0.0  0.0   2728  1524 ?        Ss   Jun21   0:00 /sbin/init
    chef-client syslog   27328  0.0  0.0  27296  1244 ?        Sl   Jun21   0:00 rsyslogd -c4
    chef-client root     27329  0.0  0.0   2368   584 ?        S    Jun21   0:00 upstart-udev-bridge --daemon
    chef-client root     27340  0.0  0.0   2236   520 ?        S<s  Jun21   0:00 udevd --daemon
    chef-client root     27364  0.0  0.0   1840   548 pts/9    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty4
    chef-client root     27368  0.0  0.0   1840   548 pts/7    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty2
    chef-client root     27369  0.0  0.0   1840   548 pts/8    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty3
    chef-client root     27371  0.0  0.0   2428   804 ?        Ss   Jun21   0:00 cron
    chef-client root     27401  0.0  0.0   1840   548 pts/6    Ss+  Jun21   0:00 /sbin/getty -8 38400 tty1
    chef-client root     27402  0.0  0.0   1840   548 pts/10   Ss+  Jun21   0:00 /sbin/getty -8 38400 /dev/console
    chef-client root     27420  0.0  0.0   2288   572 ?        Ss   Jun21   0:00 dhclient3 -e IF_METRIC=100 -pf /var/run/dhclient.eth0.pid -lf /var/lib/dhcp3/dhclient.eth0.leases eth0
    chef-client root     27437  0.0  0.1   5600  2128 ?        Ss   Jun21   0:00 /usr/sbin/sshd -D
    chef-client root     27616  0.2  1.2  26292 22128 ?        Sl   Jun21   6:00 /opt/opscode/embedded/bin/ruby /usr/bin/chef-client -d -P /var/run/chef/client.pid -L /var/log/chef/client.log -c /etc/chef/client.rb -i 1800 -s 20
    timezone   root     28244  0.0  0.0   2724  1568 ?        Ss   Jun21   0:00 /sbin/init
    timezone   root     28355  0.0  0.0   2368   600 ?        S    Jun21   0:00 upstart-udev-bridge --daemon
    timezone   syslog   28356  0.0  0.0  27296  1268 ?        Sl   Jun21   0:00 rsyslogd -c4
    timezone   root     28366  0.0  0.0   2236   504 ?        S<s  Jun21   0:00 udevd --daemon
    timezone   root     28385  0.0  0.0   1840   556 pts/14   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty4
    timezone   root     28388  0.0  0.0   1840   560 pts/12   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty2
    timezone   root     28390  0.0  0.0   1840   556 pts/13   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty3
    timezone   root     28397  0.0  0.0   2428   812 ?        Ss   Jun21   0:00 cron
    timezone   root     28423  0.0  0.0   1840   564 pts/11   Ss+  Jun21   0:00 /sbin/getty -8 38400 tty1
    timezone   root     28426  0.0  0.0   1840   560 pts/15   Ss+  Jun21   0:00 /sbin/getty -8 38400 /dev/console
    timezone   root     28449  0.0  0.0   2288   576 ?        Ss   Jun21   0:00 dhclient3 -e IF_METRIC=100 -pf /var/run/dhclient.eth0.pid -lf /var/lib/dhcp3/dhclient.eth0.leases eth0
    timezone   root     28466  0.0  0.1   5600  2124 ?        Ss   Jun21   0:00 /usr/sbin/sshd -D
    sudo       root     32737  0.0  0.0   2720  1580 ?        Ss   Jun21   0:00 /sbin/init
    users      root     32741  0.0  0.0   2232   280 ?        S<   Jun21   0:00 udevd --daemon
    users      root     32742  0.0  0.0   2232   280 ?        S<   Jun21   0:00 udevd --daemon
    chef-client root     32745  0.0  0.0   2232   280 ?        S<   Jun21   0:00 udevd --daemon
    chef-client root     32747  0.0  0.0   2232   280 ?        S<   Jun21   0:00 udevd --daemon
    timezone   root     32754  0.0  0.0   2232   272 ?        S<   Jun21   0:00 udevd --daemon
    timezone   root     32755  0.0  0.0   2232   272 ?        S<   Jun21   0:00 udevd --daemon

### Example Test Run

Here is an example of using Cucumber-Chef to do a basic test.  In this test we will provision a server called `devopserver` and apply the `chef-client::service` recipe from the `chef-client` community cookbook.  This example assumes you have your test lab provisioned and up and running.  First things first, make sure you've downloaded the `chef-client` community cookbook and placed it in your chef-repo.

Now upload the `chef-client` community cookbook to your Cucumber-Chef test lab.

    $ cc-knife cookbook upload chef-client
    Uploading chef-client             [1.1.2]
    Uploaded 1 cookbook.

Next create your `devopserver` feature.

    $ cucumber-chef create devopserver

Here is the feature we'll be using.  This feature has some extra scenarios to illustrate how you might go about testing other parts of a system.  Go into the features directory of your chef-repo and replace the contents of the `devopserver.feature` file with the text below.

    @devopserver @wip
    Feature: Perform test driven infrastructure with Cucumber-Chef
      In order to learn how to develop test driven infrastructure
      As an infrastructure developer
      I want to better understand how to use Cucumber-Chef

      Background:
        * I have a server called "devopserver"
        * "devopserver" is running "ubuntu" "lucid"
        * "devopserver" has been provisioned
        * the "chef-client::service" recipe has been added to the "devopserver" run list
        * the chef-client has been run on "devopserver"
        * I ssh to "devopserver" with the following credentials:
          | username | keyfile        |
          | root     | ../.ssh/id_rsa |

      Scenario: Can connect to the provisioned server via SSH password authentication
        And I run "hostname"
        Then I should see "devopserver" in the output

      Scenario: Default root shell is bash
        And I run "echo $SHELL"
        Then I should see "bash" in the output

      Scenario: Default gateway and resolver are using Cucumber-Chef Test Lab
        And I run "route -n | grep 'UG'"
          Then I should see "192.168.255.254" in the output
        And I run "cat /etc/resolv.conf"
          Then I should see "192.168.255.254" in the output
          And I should see "8.8.8.8" in the output
          And I should see "8.8.4.4" in the output

      Scenario: Primary interface is configured with my IP address and MAC address
        And I run "ifconfig eth0"
          Then I should see the "IP" of "devopserver" in the output
          And I should see the "MAC" of "devopserver" in the output

      Scenario: Local interface is not configured with my IP address or MAC address
        And I run "ifconfig lo"
          Then I should see "127.0.0.1" in the output
          And I should not see the "IP" of "devopserver" in the output
          And I should not see the "MAC" of "devopserver" in the output

      Scenario: Chef-Client is running as a daemon
        When I run "ps aux | grep [c]hef-client"
          Then I should see "chef-client" in the output
          And I should see "-d" in the output
          And I should see "-i 1800" in the output
          And I should see "-s 20" in the output

Now we're going to execute the test.  Created features are pre tagged with the name of the feature (i.e. `@<name>`) and `@wip`.  Be sure to pass that to the test runner so Cucumber knows to only run tests tagged with that, unless you want to test all your features.

    $ cucumber-chef test --tags @devopserver
    Using features directory: /home/couldbeyou/chef-repo/features
    Cucumber-Chef Test Runner Initalized!
    Cleaning up any previous test runs...done.
    Uploading files required for this test run...done.
    Executing Cucumber-Chef Test Runner
    Using the default profile...
    Code:
      * ./support/env.rb
      * ./devopserver/step_definitions/devopserver_steps.rb
      * ./sample/step_definitions/sample_steps.rb

    Features:
      * ./devopserver/devopserver.feature
    Parsing feature files took 0m0.076s

    @devopserver @wip
    Feature: Perform test driven infrastructure with Cucumber-Chef
      In order to learn how to develop test driven infrastructure
      As an infrastructure developer
      I want to better understand how to use Cucumber-Chef

      Background:                                                                        # ./devopserver/devopserver.feature:7
        * all servers are being destroyed
        * I have a server called "devopserver"                                           # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/provision_steps.rb:1
        * "devopserver" is running "ubuntu" "lucid"                                      # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/provision_steps.rb:5
        * devopserver is being provisioned
        * "devopserver" has been provisioned                                             # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/provision_steps.rb:25
        * the "chef-client::service" recipe has been added to the "devopserver" run list # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/provision_steps.rb:33
        * the chef-client has been run on "devopserver"                                  # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/provision_steps.rb:37
        * I ssh to "devopserver" with the following credentials:                         # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:57
          | username | keyfile        |
          | root     | ../.ssh/id_rsa |

      Scenario: Can connect to the provisioned server via SSH password authentication    # ./devopserver/devopserver.feature:17
        And I run "hostname"                                                             # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "devopserver" in the output                                    # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81

      Scenario: Default root shell is bash                                               # ./devopserver/devopserver.feature:21
        And I run "echo $SHELL"                                                          # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "bash" in the output                                           # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81

      Scenario: Default gateway and resolver are using Cucumber-Chef Test Lab            # ./devopserver/devopserver.feature:25
        And I run "route -n | grep 'UG'"                                                 # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "192.168.255.254" in the output                                # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I run "cat /etc/resolv.conf"                                                 # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "192.168.255.254" in the output                                # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should see "8.8.8.8" in the output                                         # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should see "8.8.4.4" in the output                                         # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81

      Scenario: Primary interface is configured with my IP address and MAC address       # ./devopserver/devopserver.feature:33
        And I run "ifconfig eth0"                                                        # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see the "IP" of "devopserver" in the output                        # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:90
        And I should see the "MAC" of "devopserver" in the output                        # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:90

      Scenario: Local interface is not configured with my IP address or MAC address      # ./devopserver/devopserver.feature:38
        And I run "ifconfig lo"                                                          # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "127.0.0.1" in the output                                      # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should not see the "IP" of "devopserver" in the output                     # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:90
        And I should not see the "MAC" of "devopserver" in the output                    # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:90

      Scenario: Chef-Client is running as a daemon                                       # ./devopserver/devopserver.feature:44
        When I run "ps aux | grep [c]hef-client"                                         # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:77
        Then I should see "chef-client" in the output                                    # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should see "-d" in the output                                              # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should see "-i 1800" in the output                                         # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81
        And I should see "-s 20" in the output                                           # cucumber-chef-2.0.0.rc1/lib/cucumber/chef/steps/ssh_steps.rb:81

    6 scenarios (6 passed)
    58 steps (58 passed)
    2m45.515s

If all goes well you should see output similar to what's above!  Enjoy and have fun!

# LINKS

Source:

* https://github.com/Atalanta/cucumber-chef

Issues:

* https://github.com/Atalanta/cucumber-chef/issues

Wiki:

* https://github.com/Atalanta/cucumber-chef/wiki

# LICENSE

Cucumber-Chef - A test driven infrastructure system

* Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
* Author: Zachary Patten <zachary@jovelabs.com>
* Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
* License: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
