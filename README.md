Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which Cucumber tests can be run which provision virtual machines, configure them by applying the appropriate Chef roles to them, and then run acceptance and integration tests against the environment.

## Overview

Cucumber-chef begins with a very simple premise.  If we are framing our infrastructure as code - if we're writing cookbooks, recipes and other pieces of automation in a high level programming language, such as Ruby, then it makes sense to follow the current wisdom across the software development world to maximise the quality, maintainability and reusability of our code, providing maximum chance that we'll deliver value with it.  One area which has been shown to have a very positive effect is the practive of 'test-driven' development.  In this paradigm, the developer begins by writing a test that captures the intended behaviour of the code they are going to write.  This test will start out by failing.  The developer then writes code to make the test pass, and iterates thereafter.

Cucumber-chef provides a framework to make it easier to do test-driven development for infrastructure.  It does this by providing a test infrastructure, which we call the "test lab", within which a number of different scenarios can be set up, and against which Cucumber features can we run.  From the outset, Cucumber-chef's design was to provide a fast, lightweight and cheap way to fire up virtual machines for testing.  At present this is achieved using Linux Containers on Amazon EC2.  Supporting alternative provisioning backends is planned, which will allow the user to opt to test using local machines, alternative cloud providers, and ultimatey alternative virtualization technologies.

As you might have guessed from the name, we're going to write high level acceptance tests using Cucumber.  Cucumber-Chef provides step definitions and helper methods to make it easy to provision and manage machines with Chef, and then build end-to-end tests.

## Getting Started

Getting started with Cucumber-Chef is a simple, three step process:

1) Install Cucumber-Chef
2) Integrate with Hosted Chef and Amazon EC2
3) Run cucumber-chef setup

### 1) Installing Cucumber-Chef

Installing Cucumber-Chef is simple.  It's distributed as a RubyGem, so you can simply run:

    $ gem install cucumber-chef

Once installed, you can run `cucumber-chef` on the command line to get an overview of the tasks it can carry out.

    $ cucumber-chef
    Tasks:
      cucumber-chef amis                    # List available EC2 Ubuntu AMIs
      cucumber-chef connect                 # Connect to a container in your test lab
      cucumber-chef destroy                 # Destroy running test labs
      cucumber-chef displayconfig           # Display the current config from knife.rb
      cucumber-chef help [TASK]             # Describe available tasks or one specific task
      cucumber-chef info                    # Display information about the current test labs
      cucumber-chef project <project name>  # Create a project template for testing an infrastructure
      cucumber-chef setup                   # Set up a cucumber-chef test lab in Amazon EC2
      cucumber-chef ssh                     # SSH to running test lab
      cucumber-chef test <project name>     # Run the cucumber-chef test suite <project name> from a workstation.
      cucumber-chef upload <project name>   # Upload the cucumber-chef test suite <project name> to the test lab platform

### 2) Integrate with Hosted Chef and Amazon EC2

In its current incarnation, Cucumber-Chef makes two important assumptions.  Firstly, it assumes you're using Opscode Hosted Chef rather than your own Chef server.  Secondly, it assume that you are comfortable with using Amazon's EC2 service for providing the 'bare metal' on which we set up the test lab.  Removing these assumptions, to support Chef Solo, or your own Open Source Chef server is high on the list of priorities.

Cucumber-chef is tightly integrated with Chef - it uses your knife.rb for credentials, and any cucumber-chef-specific configuration goes in knife.rb under the cucumber-chef namespace.

On installation, the first thing you should do is run:

    $ cucumber-chef displayconfig

This will look for your knife.rb, and extract the relevant sections, check them, and display them on the screen.  If any entries are missing, it will alert you.

We recommended keeping your knife.rb inside your organization's Chef repository, inside the `.chef` directory, and use environment variables to specify username, organization name and cloud provider credentials.  When run, Cucumber-chef will search for a directory called `.chef` in your current directory, and then carry on going up the directory tree until it finds one.  In practice this means that if you stay within the chef-repo directory for the organization on which you're working, Cucumber-chef will use the knife.rb in that repo; if you're elsewhere in the filesystem rooted in your home directory, and have `.chef` in your home directory, Cucumber-chef will use that.  Otherwise you'll need to either change into a directory where a `.chef` can be found, or copy, creatre or link accordingly.  In most cases we anticipate that you'll be inside the chef-repo of your organisation, and the documentation is written from this perspective.

#### 2a) Refactor 'knife.rb'

If you haven't already, refactor your knife.rb to look like this:

    current_dir  = File.dirname(__FILE__)
    user         = ENV['OPSCODE_USER'] || ENV['USER']

    log_level               :info
    log_location            STDOUT
    node_name               "#{user}"
    client_key              "#{ENV['HOME']}/.chef/#{user}.pem"
    validation_client_name  "#{ENV['ORGNAME']}-validator"
    validation_key          "#{ENV['HOME']}/.chef/#{ENV['ORGNAME']}-validator.pem"
    chef_server_url         "https://api.opscode.com/organizations/#{ENV['ORGNAME']}"
    cache_type              'BasicFile'
    cookbook_path           ["#{current_dir}/../cookbooks"]
    verbose_logging         true
    cache_options(:path => "#{ENV['HOME']}/.chef/checksums")

Now set your Hosted Chef username and organization name using environment variables:

    $ export OPSCODE_USER="platform_user_name"
    $ export ORGNAME="platform_organization"

Now put your validator and client keys in $HOME/.chef.  Verify that everything still works:

    $ knife client list

If you get results back, we're in business.

#### 2b) Configure AWS EC2 Settings in 'knife.rb'

Now add the EC2 configuration:

    # Knife EC2 Details
    # -----------------
    knife[:aws_access_key_id]         = ENV['AWS_ACCESS_KEY_ID']
    knife[:aws_secret_access_key]     = ENV['AWS_SECRET_ACCESS_KEY']
    # -----------------
    knife[:aws_ssh_key_id]            = ENV['AWS_SSH_KEY_ID'] || user
    knife[:identity_file]             = "#{ENV['HOME']}/.chef/#{user}.pem"
    # -----------------
    knife[:region]                    = "us-west-2"
    knife[:availability_zone]         = "us-west-2a"
    # -----------------
    #knife[:aws_security_group]        = "my-uber-group" # default: "cucumber-chef"
    # -----------------
    #knife[:aws_image_id]              = "ami-76fd7146"
    knife[:ubuntu_release]            = "maverick"
    # -----------------
    #knife[:aws_instance_arch]         = "amd64" # default: "i386"
    #knife[:aws_instance_disk_store]   = "ebs" # default: "instance-store"
    #knife[:aws_instance_type]         = "t1.micro" # default: "m1.small"

Note that right now Cucumber-Chef only supports Ubuntu-based test labs and LXC containers.  We have plans to support RHEL test labs and LXC containers in the near future.

The previous long term support (LTS) version of Ubuntu, Lucid, shipped with an old version of Linux Containers, which lacked some key capabilities, and as such, the host OS defaults to the next version - Maverick.  This will provide Lucid containers.  We plan to move quickly to using the latest LTS version, as Maverick is now end-of-life.  For now, the tested approach is to set `ubuntu_release` to `maverick`.  Other configurations are not yet supported.

Now set your AWS EC2 environment variables:

    $ export AWS_ACCESS_KEY_ID="SEKRITKEY"
    $ export AWS_SECRET_ACCESS_KEY="rEeLySeKrItKeY"
    $ export AWS_SSH_KEY_ID="your_aws_pem_filename_minus_extension"

    AWS_ACCESS_KEY_ID:
      Under "Sign-In Credentials", your AWS "User name"
    AWS_SECRET_ACCESS_KEY:
      Under "Access Credentials", your AWS "Access Key"
    AWS_SSH_KEY_ID:
      The ID is the name of the key file from when you created it.  For instance
      if your key was named KeyId.pem when you downloaded it, this would be KeyId

And then ensure your AWS ssh key is in place.

Now check your config again, with cucumber-chef display config.  If you get no complaints, you're ready to set up a test lab.

##### 'aws_image_id' and 'aws_instance_type'

You can specify an AMI in your EC2 configuration either directly with the `:aws_image_id` parameter or by setting the `:ubuntu_release` parameter:

    knife[:ubuntu_release] = "maverick"

You can also set the additional parameters:

    knife[:aws_instance_arch] = "amd64"
    knife[:aws_instance_disk_store] = "ebs"

`:aws_instance_arch` takes the values "i386" or "amd64" and defaults to "i386"
`:aws_instance_disk_store` takes the values "instance-store" and "ebs" and defaults to "instance-store".

If you want to specify an instance type for your test lab use the `:aws_instance_type` setting (default is "m1.small"):

    knife[:aws_instance_type] = "m1.large"

##### AWS Security Group

By default `cucumber-chef` will use a security group "cucumber-chef", creating it if it doesn't exist. You can specify another security group with the configuration setting `:aws_security_group`.

    knife[:aws_security_group] = "my-existing-security-group"

### 3) Run 'cucumber-chef' Setup


    $ cucumber-chef setup

This command will set up a complete test lab environment, As long as you've provided valid AWS and Opscode credentials, it will do this automatically.  The process takes about 15 minutes, after which you'll have a fully funtioning platform available for you to use.  Let's just quickly review what that means.  You will have an EC2 machine, fully managed by Chef, and providing the following:

* The ability to provision LXC containers
* The ability to run tests against LXC containers
* A dedicated container for certain kinds of testing scenarios

The next stage is to set up a project.  A project is simply a directory structure for containing your cucumber features and steps, already set up with an appropriate environment to make use of the step definitions provided with cucumber-chef.  We think it makes most sense to have this in your organisation's chef repo.  Cucumber-chef provides a task which will create a the directory for you, and populate it with a README and an example feature and step.


    $ cd /path/to/chef-repo
    $ cucumber-chef project example

This will create a directory, cucumber-chef, and a subdirectory, example.

    └── example
        ├── README
        └── features
            ├── example.feature
            ├── step_definitions
            │   └── example_step.rb
            └── support
                └── env.rb

## Writing Tests

Once you've got your test lab set up, and you've generated a project, it's time to crack on with writing a test.  The basic idea is this:

1) An infrastructure requirement is established
2) Write a cucumber feature that expresses the required behaviour of the infrastructure requirement
3) Write steps that will build this infrastructure environment on the test lab, using the step definitions provided - these include the ability to create a container, apply roles to it, and destroy it again.
4) Write cookbooks and recipes and supporting code to make the test pass

### Container Details

All containers operate off a bridged interface on the test-lab.  All outbound, non-local traffic from the LXC containers are NAT'd through the test-lab and off to the outside world.  This bridged interface on the test-lab is configured as follows:

    IP Address: 192.168.255.254
    Netmask: 255.255.0.0
    Broadcast: 192.168.255.255

You are free to use any IP in this class B network, with the exception of the test-lab itself, which is at `192.168.255.254`.

### Test Helpers

#### Cucumber Scenario Centric Helpers

There are several methods you will need to call in your step definitions to leverage Cucumber-Chef.  This is a brief overview of them and what they do.

* `create_server(name, ip=nil, mac=nil)`

This method will create an LXC container (i.e. server) using the supplied `name` and start it up.  Both the `ip` address and `mac` address are optional parameters.  Under normal conditions you won't need to ever specify the MAC address or, in all likelihood, the IP address unless you are creating multi-server scenarios and require fixed addresses so you can test communication between the servers.  If you do not specify an IP address one is randomly chosen and assigned to the server for the duration of the scenario.  You can fetch this IP at any time through the `@servers` instance variable using this syntax `@servers[name][:ip]`.  The MAC address can also be fetched using `@servers[name][:mac]`.

* `set_chef_client_attributes(name, attributes={})`

This method will output the supplied `attributes` to the server `name`.  These attributes are rendered as JSON and passed to the chef-client when the `run_chef` method is called.

* `run_chef(name)`

This method executes the chef-client on the server `name`.  The JSON rendered by `set_chef_client_attributes` is passed to the chef-client as well.  Currently the node_name is rendered as `cucumber-chef-#{name}`.

##### Examples

    Given /^a newly bootstrapped server$/ do
      create_server("devopserver")
    end

    When /^the devops users recipe is applied$/ do
      set_chef_client_attributes("devopserver", :run_list => ["recipe[users::devops]"])
      run_chef("devopserver")
    end

#### Cucumber Before Hook Centric Helpers

* `set_chef_client(attributes={})`

This method configures the base attributes used to render the chef-client's `client.rb` file.  Currently you can specify `:orgname`, `:log_level`, `:log_location`, `:chef_server_url` and `:validation_client_name`.

##### Examples

    Before do
      set_chef_client(:orgname => "cucumber-chef")
    end

## Running Tests

You can write the tests and Chef code wherever you like.  We're assuming you prefer working on your local machine, and checking into version control.  But we don't really care.  When it's time to run tests, cucumber-chef provides a task which handles this:

    $ cucumber-chef test myproject

At the moment cucumber-chef doesn't pass though clever filtering and tagging options that cucumber supports - you run all the tests.  We're going to improve that soon, again, patches and pull requests very welcome.

Running the test task will upload your current project to the test lab, and run the tests, reporting the results back to the screen. Cucumber-chef also provides an upload task, so you can push the current project to the test lab, and then connect to test lab yourself to run tests in a more granular way.  To do this, you need to know the IP of the test lab.  You can find this out by running:

    $ cucumber-chef info

At present, Cucumber-Chef only allows one test lab per AWS account and Opscode Hosted Chef account.

### Example Test Run

Running infrastructure tests are very slow due to the nature of what is involved.  Currently Cucumber-Chef builds a clean LXC container before each scenario to avoid carrying over tainted or corrupted data from a previous scenario run.  We have plans to support libvirt so test-labs can be moved locally to take advantage of SSD drives which will undoubtedly speed up these tests considerably.

    $ bin/cucumber-chef test devops
    Verifing Configuration...
    Cucumber-Chef Test Runner Initalized!
      * 1.2.3.4: (SSH) 'rm -rf /home/ubuntu/devops'
      * 1.2.3.4: (SCP) 'cucumber-chef/devops' -> '/home/ubuntu/devops'
      * 1.2.3.4: (SSH) 'sudo cucumber -c -v -b /home/ubuntu/devops/features'
    Code:
      * /home/ubuntu/devops/features/support/env.rb
      * /home/ubuntu/devops/features/step_definitions/devops_ssh_steps.rb

    Features:
      * /home/ubuntu/devops/features/devops_ssh.feature
    Parsing feature files took 0m0.004s

    Feature: devops can log into server

      Scenario: devops can connect to server via ssh key # /home/ubuntu/devops/features/devops_ssh.feature:3
      * 192.168.230.204: (LXC) 'devopserver' Building
      * 192.168.230.204: (LXC) 'devopserver' Booted
      * 192.168.230.204: (LXC) 'devopserver' Ready
        Given a newly bootstrapped server                # devops/features/step_definitions/devops_ssh_steps.rb:1
        When the devops users recipe is applied          # devops/features/step_definitions/devops_ssh_steps.rb:5
        Then a devop should be able to ssh to the server # devops/features/step_definitions/devops_ssh_steps.rb:10

      Scenario: Default shell is bash              # /home/ubuntu/devops/features/devops_ssh.feature:8
      * 192.168.50.105: (LXC) 'devopserver' Building
      * 192.168.50.105: (LXC) 'devopserver' Booted
      * 192.168.50.105: (LXC) 'devopserver' Ready
        Given a newly bootstrapped server          # devops/features/step_definitions/devops_ssh_steps.rb:1
        When the devops users recipe is applied    # devops/features/step_definitions/devops_ssh_steps.rb:5
        And a devop connects to the server via ssh # devops/features/step_definitions/devops_ssh_steps.rb:29
        Then their login shell should be "bash"    # devops/features/step_definitions/devops_ssh_steps.rb:36

    2 scenarios (2 passed)
    7 steps (7 passed)
    2m50.620s
