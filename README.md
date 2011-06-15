Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which cucumber tests can be run which provision lightweight virtual machines, configure them by applying the appriporaite Chef roles to them, and then run acceptance and integration tests against the environment.

## Installation 

Cucumber-chef is distributed as a gem.  Until it's published on Rubygems, you'll need to build the gem yourself.  Check the project out, and then build and install the gem.

First ensure you have bundler available, and then run:

    $ bundle install

Cucumber-chef uses Jeweler (see https://github.com/technicalpickles/jeweler) for managing gem builds , publishing and dependencies.  To build the gem simply run:

    $ rake build

This will result in the gem appearing in pkg/.  Install it:

    $ gem install pkg/cucumber-chef-0.0.4.gem

## Overview

Cucumber-chef begins with a very simple premise.  If we are framing our infratructure as code - if we're writing cookbooks, recipes and other pieces of automation in a high level programming language, such as Ruby, then it makes sense to follow the current wisdom across the software development world to maximise the quality, maintainability and reusability of our code, providing maximum chance that we'll deliver value with it.  One area which has been shown to have a very positive effect is the practive of 'test-driven' development.  In this paradigm, the developer begins by writing a test that captures the intended behaviour of the code  they are going to write.  This test will start out by failing.  The developer then writes code to make the test pass, and iterates thereafter.  

Cucumber-chef provides a framework to make it easier to do test-driven development for infrastructure.

### Vocabulary

Throughout this documentation, a few terms will crop up regularly.  It makes sense to define these up front, as they're just terms we've been using since we started writing cucumber-chef.  They may even change, but in the meantime, so we're all n the same page, here are some of the terms we use:

* Test Lab: An environment made up (at present) of an EC2 instance, configured to be an LXC host.  This machine does nothing other than provide space in which Linux containers can be created and destroyed.
* Controller: One special Linux container which acts as the central point from which tests are run.  This machine is where the tests run, and has connectivity and credentials to connect to the machines that are created as part of a test run.
* Container: A container is a lightweight virtual machine - it is entirely self-contained, with its own process tree, resource constraints, filesystem and network stack.  It shares a kernel with the Test Lab host server.

## Getting started

Cucumber-chef is tightly integrated with Chef - it uses your knife.rb for credentials, and any cucumber-chef-specific configuration goes in knife.rb under the cucumber-chef namespace.

On installation, the first thing you should do is run:

    $ cucumber-chef displayconfig

This will look for your knife.rb, and extract the relevant sections, check them, and display them on the screen.  If any entries are missing, it will alert you.

The current recommendation is to keep your knife.rb inside your organisation's chef repository, in .chef, and use environment variables to specify username, organisation name and cloud provider credentials.  Cucumber-chef supports and encourages this approach.  It will search for a directory called .chef in your current directory, and then carry on going up the directory tree until it finds one.  In practice this means that if you stay within the chef-repo directory for the organisation on which you're working, cucumber-chef will use the knife.rb; if your elsewhere in the filesystem rooted in your home directory, and have .chef in your home directory, cucumber-chef will use that.  Otherwise you'll need to either change into a directory where a .chef can be found, or copy, creatre or link accordingly.  In most cases we anticipate that you'll be inside the chef-repo of your organisation, and the documentation is written from this perspective.

In its current incarnation, cucumber-chef makes two important assumptions.  Firstly, we assume you're using the Opscode platform rather than your own Chef server.  Secondly, we assume that you are comfortable with using Amazon's EC2 service for providing the 'bare metal' on which we set up the test lab.  Future releases may well allow you to use your own Chef server, and will definitely look at offering alternative cloud providers.  In the meantime, we welcome patches and pull requests!

Set your environment variables:

    $ export OPSCODE_USER=platform_user_name
    $ export ORGNAME=platform_organisation
    $ export AWS_ACCESS_KEY_ID=SEKRITKEY
    $ export AWS_SECRET_ACCESS_KEY=REELYSEKRITKEY

Now check your config again, with cucumber-chef display config.  If you get no complaints, you're ready to set up a test lab.

    $ cucumber-chef setup

This command will set up a complete test lab environment, including a controller.  As long as you've provided valid AWS and Opscode credentials, it will do this automatically.  The process takes about 12 minutes, after which you'll have a fully funtioning platform available for you to use.

The next stage is to set up a project.  A project is simply a directory structure for containing your cucumber features and steps, already set up with an appropriate environment to make use of the step definitions provided with cucumber-chef.  We think it makes most sense to have this in your organisation's chef repo.  Cucumber-chef provides a task which will create a the directory for you, and populate it with a README and an example feature and step.

    $ cucumber-chef project someproject

**TO DO: fix this....**

## Writing tests

Once you've got your test lab set up, and you've generated a project, it's time to crack on with writing a test.  The basic idea is this:

1) An infrastructure requirement is established
2) Write a cucumber feature that expresses the required behaviour of the infrastructure requirement
3) Write steps that will build this infrastructure environment on the test lab, using the step definitions provided - these include the ability to create a container, apply roles to it, and destroy it again.
4) Write cookbooks and recipes and supporting code to make the test pass

## Running tests

You can write the tests and Chef code wherever you like.  We're assuming you prefer working on your local machine, and checking into version control.  But we don't really care.  When it's time to run tests, cucumber-chef provides a task which handles this:

    $ cucumber-chef test myproject

At the moment cucumber-chef doesn't pass though clever filtering and tagging options that cucumber supports - you run all te tests.  We're going to improve that soon, again, patches and pull requests very welcome.

Running the test task will upload your current project to the controller, and run the tests.
