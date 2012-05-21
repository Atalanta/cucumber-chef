Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which cucumber tests can be run which provision lightweight virtual machines, configure them by applying the appriporaite Chef roles to them, and then run acceptance and integration tests against the environment.

## Overview

Cucumber-chef begins with a very simple premise.  If we are framing our infrastructure as code - if we're writing cookbooks, recipes and other pieces of automation in a high level programming language, such as Ruby, then it makes sense to follow the current wisdom across the software development world to maximise the quality, maintainability and reusability of our code, providing maximum chance that we'll deliver value with it.  One area which has been shown to have a very positive effect is the practive of 'test-driven' development.  In this paradigm, the developer begins by writing a test that captures the intended behaviour of the code  they are going to write.  This test will start out by failing.  The developer then writes code to make the test pass, and iterates thereafter.

Cucumber-chef provides a framework to make it easier to do test-driven development for infrastructure.  It does this by providing a test infrastructure, in the cloud, which provides a very fast, lightweight and cheap way to fire up virtual machines for testing.  We call this the "test lab".

As you might have guessed from the name, we're going to write high level acceptance tests using Cucumber.  Cucumber-Chef provides step definitions and helper methods to make it easy to provision and manage machines with Chef, and then build end-to-end tests.

## Getting started

Getting started with Cucumber-Chef is a simple, three step process:

1) Install Cucumber-Chef
2) Integrate with Hosted Chef and Amazon EC2
3) Run cucumber-chef setup

### Installing Cucumber-Chef

Installing Cucumber-Chef is simple.  It's distributed as a RubyGem, so you can simply run:

    $ gem install cucumber-chef

Once installed, you can run cucumber-chef on the command line to get an overview of the tasks it can carry out.

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

### Integrate with Hosted Chef and Amazon EC2

In it's current incarnation, Cucumber-Chef makes two important assumptions.  Firstly, it assumes you're using Opscode Hosted Chef rather than your own Chef server.  Secondly, it assume that you are comfortable with using Amazon's EC2 service for providing the 'bare metal' on which we set up the test lab.

Cucumber-chef is tightly integrated with Chef - it uses your knife.rb for credentials, and any cucumber-chef-specific configuration goes in knife.rb under the cucumber-chef namespace.

On installation, the first thing you should do is run:

    $ cucumber-chef displayconfig

This will look for your knife.rb, and extract the relevant sections, check them, and display them on the screen.  If any entries are missing, it will alert you.

The recommended best practice for Chef is to keep your knife.rb inside your organisation's Chef repository, inside the .chef directory, and use environment variables to specify username, organisation name and cloud provider credentials.  Cucumber-chef supports and encourages this approach.  It will search for a directory called .chef in your current directory, and then carry on going up the directory tree until it finds one.  In practice this means that if you stay within the chef-repo directory for the organisation on which you're working, cucumber-chef will use the knife.rb; if your elsewhere in the filesystem rooted in your home directory, and have .chef in your home directory, cucumber-chef will use that.  Otherwise you'll need to either change into a directory where a .chef can be found, or copy, creatre or link accordingly.  In most cases we anticipate that you'll be inside the chef-repo of your organisation, and the documentation is written from this perspective.

If you haven't already, refactor your knife.rb to look like this:

    current_dir = File.dirname(__FILE__)
    user = ENV['OPSCODE_USER'] || ENV['USER']
    log_level :info
    log_location STDOUT
    node_name user
    client_key "#{ENV['HOME']}/.chef/#{user}.pem"
    validation_client_name "#{ENV['ORGNAME']}-validator"
    validation_key "#{ENV['HOME']}/.chef/#{ENV['ORGNAME']}-validator.pem"
    chef_server_url "https://api.opscode.com/organizations/#{ENV['ORGNAME']}"
    cache_type 'BasicFile'
    cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
    cookbook_path ["#{current_dir}/../cookbooks"]

Now set your Hosted Chef username and organization name using environment variables:

    $ export OPSCODE_USER=platform_user_name
    $ export ORGNAME=platform_organisation

Now put your validator and client keys in $HOME/.chef.  Verify that everything still works:

    $ knife client list

If you get results back, we're in business.

Now add the EC2 configuration:

    knife[:aws_access_key_id] = ENV['AWS_ACCESS_KEY_ID']
    knife[:aws_secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY']
    knife[:aws_ssh_key_id] = ENV['AWS_SSH_KEY_ID']
    knife[:identity_file] = "/path/to/aws_ssh_key.pem"
    knife[:availability_zone] = "eu-west-1a"
    knife[:region] = "eu-west-1"
    knife[:aws_image_id] = "ami-339ca947"

Note that right now Cucumber-Chef only supports Ubuntu-based  test labs.

Set your environment variables:

    $ export AWS_ACCESS_KEY_ID=SEKRITKEY
    $ export AWS_SECRET_ACCESS_KEY=REELYSEKRITKEY
    $ export AWS_SSH_KEY_ID

And then ensure your AWS ssh key is in place.

Now check your config again, with cucumber-chef display config.  If you get no complaints, you're ready to set up a test lab.

#### AWS image id and instance type

You can specify an AMI in your EC2 configuration either directly with the `:aws_image_id` parameter or by setting the `:ubuntu release` parameter:

    knife[:ubuntu_release] = "lucid"

You can also set the additional parameters:

    knife[:aws_instance_arch] = "amd64"
    knife[:aws_instance_disk_store] = "ebs"

`:aws_instance_arch` takes the values "i386" or "amd64" and defaults to "i386", `:aws_instance_disk_store` takes the values "instance-store" and "ebs" and defaults to "instance-store".

If you want to specify an instance type for your test lab use the `:aws_instance_type` setting (default is "m1.small"):

    knife[:aws_instance_type] = "m1.large"

#### AWS security group

By default `cucumber-chef` will use a security group "cucumber-chef", creating it if it doesn't exist. You can specify another security group with the configuration setting `:aws_security_group`.

    knife[:aws_security_group] = "my-existing-security-group"

### Run cucumber-chef setup


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

## Writing tests

Once you've got your test lab set up, and you've generated a project, it's time to crack on with writing a test.  The basic idea is this:

1) An infrastructure requirement is established
2) Write a cucumber feature that expresses the required behaviour of the infrastructure requirement
3) Write steps that will build this infrastructure environment on the test lab, using the step definitions provided - these include the ability to create a container, apply roles to it, and destroy it again.
4) Write cookbooks and recipes and supporting code to make the test pass

## Running tests

You can write the tests and Chef code wherever you like.  We're assuming you prefer working on your local machine, and checking into version control.  But we don't really care.  When it's time to run tests, cucumber-chef provides a task which handles this:

    $ cucumber-chef test myproject

At the moment cucumber-chef doesn't pass though clever filtering and tagging options that cucumber supports - you run all the tests.  We're going to improve that soon, again, patches and pull requests very welcome.

Running the test task will upload your current project to the test lab, and run the tests, reporting the results back to the screen. Cucumber-chef also provides an upload task, so you can push the current project to the test lab, and then connect to test lab yourself to run tests in a more granular way.  To do this, you need to know the IP of the test lab.  You can find this out by running:

    $ cucumber-chef info

At present, Cucumber-Chef only allows one test lab per AWS account and Opscode Hosted Chef account.


