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

    $ git clone git://github.com/Atalanta/cucumber-chef -b 2.0.0.rc1
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
      cucumber-chef create <project>                   # Create a project template for testing an infrastructure.
      cucumber-chef diagnose <container>               # Provide diagnostics from the chef-client on the specified container.
      cucumber-chef displayconfig                      # Display the current cucumber-chef config.
      cucumber-chef help [TASK]                        # Describe available tasks or one specific task
      cucumber-chef info                               # Display information about the current test lab.
      cucumber-chef init                               # Initalize cucumber-chef configuration
      cucumber-chef setup                              # Setup cucumber-chef test lab in Amazon EC2
      cucumber-chef ssh [container]                    # SSH to cucumber-chef test lab or [container] if specified.
      cucumber-chef teardown                           # Teardown cucumber-chef test lab in Amazon EC2
      cucumber-chef test <project> [cucumber-options]  # Test a project using the cucumber-chef test suite.

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

### Test Helpers

#### Cucumber Scenario Centric Helpers

There are several methods you will need to call in your step definitions to leverage Cucumber-Chef.  This is a brief overview of them and what they do.

* `server_create(name, attributes={})`

This method will create an LXC container (i.e. server) using the supplied `name` and start it up.  `attributes` are optional; currently you can specify `:ip`, `:mac` and `:persist` for attributes.  You can also assign data to any other keys not used by Cucumber-Chef and access them later on in other scenarios.  In all likelihood, under normal conditions you will not need to assign a specific IP address or MAC address unless you are creating a multi-server scenario test and require fixed addresses on servers due to the nature of your tests.  If you do not specify an IP address or MAC address then they are randomly generated and assigned to the server for the duration of the scenario, unless you mark the server as persistant in which case it will retain the initially assigned IP and MAC address for the duration of the test run.  You can fetch attributes at any time through the `$servers` global variable using this syntax `$servers[name][attribute]`.  For example to get the IP address one would use `$servers[name][:ip]`; for the MAC address you would use `$servers[name][:mac]`.

* `chef_set_client_attributes(name, attributes={})`

This method will assign the supplied chef-client `attributes` to the server `name`.  These attributes are rendered as JSON and passed to the chef-client when the `chef_run_client` method is called.

* `chef_run_client(name)`

This method executes the chef-client on the server `name`.  The JSON rendered by `chef_set_client_attributes` is passed to the chef-client as well.  Currently the node_name is rendered as `cucumber-chef-#{name}`.

##### Examples

    Given /^a newly bootstrapped server$/ do
      server_create("devopserver")
    end

    When /^the devops users recipe is applied$/ do
      chef_set_client_attributes("devopserver", :run_list => ["recipe[users::devops]"])
      chef_run_client("devopserver")
    end

#### Cucumber Before Hook Centric Helpers

* `chef_set_client_config(config={})`

This method configures the chef-client's `client.rb` file.  Currently you can specify `:orgname`, `:log_level`, `:log_location`, `:chef_server_url` and `:validation_client_name`.

##### Examples

    # for Opscode Hosted chef-server use this:
    #chef_set_client_config(:orgname => "cucumber-chef")

    # for Opscode OS chef-server on the Cucumber-Chef test lab use this:
    chef_set_client_config(:chef_server_url => "http://192.168.255.254:4000",
                           :validation_client_name => "chef-validator")

## Running Tests

You can write the tests and Chef code wherever you like.  We're assuming you prefer working on your local machine, and checking into version control.  But we don't really care.  When it's time to run tests, Cucumber-Chef provides a task which handles this:

    $ cucumber-chef test myproject

You can now pass in options for cucumber or even setup profiles via `cucumber.yml`.  Any command-line options specified after the project name will be passed on to cucumber.  For example:

    $ cucumber-chef test myproject --tags @wip -c -v -b

To take advantage of cucumber profiles, create a `cucumber.yml` configuration file in your `.cucumber-chef` directory off your chef-repo.  In this file you can take full advantage of the Cucumber profiles as definied on their wiki, https://github.com/cucumber/cucumber/wiki/cucumber.yml.

    └── .cucumber-chef/
        └── cucumber.yml

Here is an example `cucumber.yml` which turns on colored output, verbosity and full backtraces for all test runs:

    ---
    default: -c -v -b

Running the test task will upload your current project to the test lab, and run the tests, reporting the results back to the screen. Cucumber-chef also provides an upload task, so you can push the current project to the test lab, and then connect to test lab yourself to run tests in a more granular way.  To do this, you need to know the IP of the test lab.  You can find this out by running:

    $ cucumber-chef info

At present, Cucumber-Chef only allows one test lab per AWS account.  In practice, this has not been a constraint.  LXC is incredibly lightweight, and a large number of containers can be provisioned on even a small EC2 instance.

### When Things Go Oh So Wrong

We have put in a few tasks to help you diagnose any issues you may come across with the test lab, containers or your cookbooks and recipes.  There are two main tasks available to help you with this: `ssh` and `diagnose`.

* `ssh`

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

* `diagnose`

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

### Example Test Run

Running infrastructure tests are very slow due to the nature of what is involved.  Currently Cucumber-Chef builds a clean LXC container before each scenario to avoid carrying over tainted or corrupted data from a previous scenario run.  We have plans to support libvirt so test-labs can be moved locally to take advantage of SSD drives which will undoubtedly speed up these tests considerably.

    $ bin/cucumber-chef test devops
    Cucumber-Chef Test Runner Initalized!
    Code:
      * /home/ubuntu/devops/features/support/env.rb
      * /home/ubuntu/devops/features/step_definitions/devops_ssh_steps.rb

    Features:
      * /home/ubuntu/devops/features/devops_ssh.feature
    Parsing feature files took 0m0.004s

    Feature: devops can log into server

      Scenario: devops can connect to server via ssh key # /home/ubuntu/devops/features/devops_ssh.feature:3
      * 192.168.230.204: (LXC) 'devopserver' Building
      * 192.168.230.204: (LXC) 'devopserver' Ready
        Given a newly bootstrapped server                # devops/features/step_definitions/devops_ssh_steps.rb:1
        When the devops users recipe is applied          # devops/features/step_definitions/devops_ssh_steps.rb:5
        Then a devop should be able to ssh to the server # devops/features/step_definitions/devops_ssh_steps.rb:10

      Scenario: Default shell is bash              # /home/ubuntu/devops/features/devops_ssh.feature:8
      * 192.168.50.105: (LXC) 'devopserver' Building
      * 192.168.50.105: (LXC) 'devopserver' Ready
        Given a newly bootstrapped server          # devops/features/step_definitions/devops_ssh_steps.rb:1
        When the devops users recipe is applied    # devops/features/step_definitions/devops_ssh_steps.rb:5
        And a devop connects to the server via ssh # devops/features/step_definitions/devops_ssh_steps.rb:29
        Then their login shell should be "bash"    # devops/features/step_definitions/devops_ssh_steps.rb:36

    2 scenarios (2 passed)
    7 steps (7 passed)
    2m50.620s
