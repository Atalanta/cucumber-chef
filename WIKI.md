[![Build Status](https://secure.travis-ci.org/zpatten/cucumber-chef.png)](http://travis-ci.org/zpatten/cucumber-chef)
[![Dependency Status](https://gemnasium.com/zpatten/cucumber-chef.png)](https://gemnasium.com/zpatten/cucumber-chef)

I was not particularly happy with the state of the 2.x documents and considering workflow changes, etc it made sense to me to start over with the documentation.  Since most things are the same the 2.x documentation will remain available in the repo as `WIKI.2.x.md`.  This is WIP.

# Cucumber-Chef 3.x Documentation

Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which Cucumber tests can be run which provision virtual machines, configure them by applying the appropriate Chef roles to them, and then run acceptance and integration tests against the environment.

# Example Chef-Repo

I have prepared a chef-repo which I use to develop off of and made it available to the community to use as a baseline for playing with cucumber-chef and experimenting with cucumber-chef.

* https://github.com/zpatten/cc-chef-repo


# Prerequsites/Recommendations

Your Chef-Repo should be setup in a manner as follows:

* Use something like RVM for your ruby with your chef-repo
* Use something like bundler for your rubygems with your chef-repo
* Use something like berkshelf for your chef cookbooks with your chef-repo

If you do not use these patterns you will have an unplesant time in general.

When using Cucumber-Chef, especially at first, I highly recommend you tail the log.  Open another terminal, naviagate to your Chef-Repo root directory and run `tail -f .cucumber-chef/cucumber-chef.log`.  You'll have a much better idea what's going on in the background this way, especially during bootstrapping and provisioning.  And root causes of issues that are not so obvious on the console will hopefully be very obvious in the log.

# Workflow

1. `cucumber`/`rspec` is executed; cucumber-chef is called
2. `cucumber-chef` (re)creates the ecosystem from the `Labfile` (optionally executed)
3. `cucumber-chef` runs the chef-client across the ecosystem using attributes from the `Labfile` (optionally executed)
4. `cucumber`/`rspec` resumes execution

# Execution

1. Ensure you have the latest vagrant and virtualbox installed.
2. `cucumber-chef init` to initalize a disabled config template
1. `cucumber-chef destroy` is executed if you want to destroy your test lab. (optional)
2. `cucumber-chef setup` is executed to ensure your test lab is provisioned. (optional, first-run)
3. `cucumber` to execute features located in your `chef-repo`.

For example when I am testing, I often use this command sequence (I use binstubs, so everything will be prefixed with bin/):

    echo "yes" | bin/cucumber-chef destroy && bin/cucumber-chef setup && bin/cucumber

This will destroy the current test lab (if one exists), setup a new test (since we destroyed any existing labs), then execute the cucumber features.

To force destruction of the containers when running cucumber place `PURGE=1` before your cucumber command like so:

    PURGE=1 bin/cucumber

# Configuration

Cucumber-Chef creates a home directory for itself named `.cucumber-chef` off the root of your Chef-Repo.  Here you can find the configuration files as well as logs and artifacts from test runs.  There are two main configuration files for Cucumber-Chef.  The `Labfile` in the Chef-Repo directory and `config.rb` in the Cucumber-Chef home directory.

## `Labfile`

When doing integration testing it makes sense that one generally wants to test across an entire ecosystem of servers.  You typically acquire a set of virtual or bare metal servers, provision those servers acordingly, put them into play then rinse and repeat.  I introduce the `Labfile`, the concept is simple if you haven't already guessed it.  You define a set of servers, i.e. an ecosystem, also dictating the settings and configuration.  Part of this change is because a) it makes alot of sense to me and b) it greatly decreases runtimes.  Also in cucumber-chef 2.x, we had insane background sections which bothered me tremendously and this change cleans up all of that mess as well.  The ultimate goal is to support configuration of multiple ecosystems, but we've got other ground to cover first so that feature will have to wait for a bit.  The `Labfile` should reside in the root of your Chef-Repo.

Here is a sample of what a `Labfile` might look like:

    #!/usr/bin/env ruby
    #^syntax detection

    ecosystem "mockup-app-1" do

      container "nginx-lb-test-1" do # or apache-lb-test-1
        distro "ubuntu"
        release "lucid"
        persist true
        ip "192.168.32.100"
        mac "00:00:5e:d1:fa:08"
        chef_client  ({ :environment => "test",
                        :run_list => [
                          "role[base]",
                          "role[nginx_lb_server]"
                        ]
                      })
      end

      container "nginx-unicorn-test-1" do # or apache-passenger-test-1
        distro "ubuntu"
        release "lucid"
        persist true
        ip "192.168.32.200"
        mac "00:00:5e:eb:8d:d3"
        chef_client  ({ :environment => "test",
                        :run_list => [
                          "role[base]",
                          "role[nginx_unicorn_server]"
                        ]
                      })
      end

      container "redis-test-1" do
        distro "ubuntu"
        release "lucid"
        persist true
        ip "192.168.32.210"
        mac "00:00:5e:eb:8d:a3"
        chef_client  ({ :environment => "test",
                        :run_list => [
                          "role[base]",
                          "role[redis_server]"
                        ]
                      })
      end

      container "mysql-test-1" do
        distro "ubuntu"
        release "lucid"
        persist true
        ip "192.168.32.220"
        mac "00:00:5e:ea:fe:28"
        chef_client  ({ :environment => "test",
                        :run_list => [
                          "role[base]",
                          "role[mysql_server]"
                        ]
                      })
      end

    end

## `config.rb`

If you want to see how your cucumber-chef installation is configured run `cucumber-chef displayconfig`:

    $ cucumber-chef displayconfig
    cucumber-chef v3.0.3
    --------------------------------------------------------------------------------
    ---
    :mode: :user
    :prerelease: false
    :user: zpatten
    :artifacts:
      chef-client-log: /var/log/chef/client.log
      chef-client-stacktrace: /var/chef/cache/chef-stacktrace.out
    :chef:
      :version: 10.24.0
      :container_version: 10.18.2
      :default_password: p@ssw0rd1
      :render_client_rb: true
      :cookbook_paths:
      - cookbooks
      - site-cookbooks
    :test_lab:
      :hostname: cucumber-chef
      :tld: test-lab
    :command_timeout: 1800
    :provider: :vagrant
    :aws:
      :bootstrap_user: ubuntu
      :lab_user: cucumber-chef
      :lxc_user: root
      :ssh:
        :lab_port: 22
        :lxc_port: 22
      :ubuntu_release: precise
      :aws_instance_arch: i386
      :aws_instance_disk_store: ebs
      :aws_instance_type: c1.medium
      :aws_security_group: cucumber-chef
      :identity_file:
      :aws_access_key_id:
      :aws_secret_access_key:
      :aws_ssh_key_id:
      :region: us-west-2
      :availability_zone: us-west-2a
    :vagrant:
      :bootstrap_user: vagrant
      :lab_user: cucumber-chef
      :lxc_user: root
      :ssh:
        :lab_ip: 192.168.33.10
        :lab_port: 22
        :lxc_port: 22
      :cpus: 4
      :memory: 4096
      :identity_file: /home/zpatten/.vagrant.d/insecure_private_key

    --------------------------------------------------------------------------------
                   root_dir = "/home/zpatten/code/cc-chef-repo/vendor/checkouts/cucumber-chef"
                   home_dir = "/home/zpatten/code/cc-chef-repo/.cucumber-chef"
                   log_file = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/cucumber-chef.log"
              artifacts_dir = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/artifacts"
                  config_rb = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/config.rb"
                    labfile = "/home/zpatten/code/cc-chef-repo/Labfile"
                  chef_repo = "/home/zpatten/code/cc-chef-repo"
                  chef_user = "zpatten"
              chef_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/zpatten.pem"
             bootstrap_user = "vagrant"
    bootstrap_user_home_dir = "/home/vagrant"
         bootstrap_identity = "/home/zpatten/.vagrant.d/insecure_private_key"
                   lab_user = "cucumber-chef"
          lab_user_home_dir = "/home/cucumber-chef"
               lab_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/id_rsa-cucumber-chef"
                   lxc_user = "root"
          lxc_user_home_dir = "/root"
               lxc_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/id_rsa-root"
                chef_pre_11 = true
    --------------------------------------------------------------------------------

You can customize your configuration by editing your `<chef-repo>/.cucumber-chef/config.rb` file.  Here's an example of the current one I'm using for testing:

    provider        :vagrant

    vagrant.merge!( :identity_file => "#{ENV['HOME']}/.vagrant.d/insecure_private_key",
                    :ssh => {
                        :lab_ip => "192.168.33.10",
                        :lab_port => 22,
                        :lxc_port => 22
                    },
                    :cpus => 4,
                    :memory => 4096 )

    aws.merge!(     :identity_file => ENV['AWS_IDENTITY'],
                    :ssh => {
                        :lab_port => 22,
                        :lxc_port => 22
                    },
                    :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
                    :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
                    :aws_ssh_key_id => ENV['AWS_SSH_KEY_ID'],
                    :region => "us-west-2",
                    :availability_zone => "us-west-2a",
                    :aws_instance_arch => "i386",
                    :aws_instance_type => "c1.medium" )

    artifacts       ({ "chef-client-log" => "/var/log/chef/client.log",
                       "chef-client-stacktrace" => "/var/chef/cache/chef-stacktrace.out" })

    chef.merge!(    :version => "10.24.0",
                    :container_version => "10.18.2",
                    :cookbook_paths => %w(cookbooks site-cookbooks))

    # chef.merge!(    :version => "10.24.0")
    # chef.merge!(    :version => "11.4.0")
    # chef.merge!(    :version => "latest")


# Cucumber-Chef Tasks

All tasks should function in a similar manner across all providers.

## `cucumber-chef help`

    $ cucumber-chef help
    Tasks:
      cucumber-chef create <project>           # Create a project template for testing an infrastructure.
      cucumber-chef destroy [container] [...]  # Destroy the cucumber-chef test lab or a single or multiple containers if specified
      cucumber-chef diagnose <container>       # Provide diagnostics from the chef-client on the specified container.
      cucumber-chef displayconfig              # Display the current cucumber-chef config.
      cucumber-chef down                       # Power off the cucumber-chef test lab
      cucumber-chef genip                      # Generate an RFC compliant private IP address
      cucumber-chef genmac                     # Generate an RFC compliant private MAC address
      cucumber-chef help [TASK]                # Describe available tasks or one specific task
      cucumber-chef info                       # *DEPRECIATED* - You should execute the 'status' task instead.
      cucumber-chef init                       # Initalize cucumber-chef configuration
      cucumber-chef log                        # Streams the cucumber-chef local and test lab logs to the terminal.
      cucumber-chef ps [ps-options]            # Snapshot of the current cucumber-chef test lab container processes.
      cucumber-chef reload                     # Reload the cucumber-chef test lab
      cucumber-chef setup                      # Setup the cucumber-chef test lab
      cucumber-chef ssh [container]            # SSH to cucumber-chef test lab or [container] if specified
      cucumber-chef status                     # Displays the current status of the test lab.
      cucumber-chef teardown                   # *DEPRECIATED* - You should execute the 'destroy' task instead.
      cucumber-chef test                       # *DEPRECIATED* - You should execute 'cucumber' or 'rspec' directly.
      cucumber-chef up                         # Power up the cucumber-chef test lab


## `cucumber-chef setup`

Setup the cucumber-chef test lab:

    $ cucumber-chef setup
    cucumber-chef v3.0.0.rc.0
    Creating VAGRANT instance completed in 53.2361 seconds.
    Bootstrapping VAGRANT instance completed in 757.4014 seconds.
    Waiting for the chef-server completed in 0.1007 seconds.
    Waiting for the chef-server-webui completed in 0.1007 seconds.
    Downloading chef-server credentials completed in 1.2088 seconds.
    Uploading 'cucumber-chef' cookbooks completed in 6.8571 seconds.
    Uploading 'cucumber-chef' roles completed in 5.5413 seconds.
    Performing chef-client run completed in 45.9874 seconds.
    Downloading proxy SSH credentials completed in 0.3013 seconds.
    Rebooting the test lab completed in 21.2672 seconds.
    Waiting for the chef-server completed in 0.1008 seconds.
    Waiting for the chef-server-webui completed in 0.1009 seconds.

    If you are using AWS, be sure to log into the chef-server webui and change the default admin password at least.

    Your test lab has now been provisioned!  Enjoy!

    +-------------------------------------------------------------------+
    |                      PROVIDER: Cucumber::Chef::Provider::Vagrant  |
    |                            ID: default                            |
    |                         STATE: running                            |
    |                      USERNAME: vagrant                            |
    |                    IP ADDRESS: 127.0.0.1                          |
    |                          PORT: 2222                               |
    |               CHEF-SERVER API: http://127.0.0.1:4000              |
    |             CHEF-SERVER WEBUI: http://127.0.0.1:4040              |
    |      CHEF-SERVER DEFAULT USER: admin                              |
    |  CHEF-SERVER DEFAULT PASSWORD: p@ssw0rd1                          |
    +-------------------------------------------------------------------+

## `cucumber-chef destroy [container] [...]`

Destroy the cucumber-chef test lab:

    $ cucumber-chef destroy
    cucumber-chef v3.0.0.rc.0
    +-------------------------------------------------------------------+
    |                      PROVIDER: Cucumber::Chef::Provider::Vagrant  |
    |                            ID: default                            |
    |                         STATE: running                            |
    |                      USERNAME: vagrant                            |
    |                    IP ADDRESS: 127.0.0.1                          |
    |                          PORT: 2222                               |
    |               CHEF-SERVER API: http://127.0.0.1:4000              |
    |             CHEF-SERVER WEBUI: http://127.0.0.1:4040              |
    |      CHEF-SERVER DEFAULT USER: admin                              |
    |  CHEF-SERVER DEFAULT PASSWORD: p@ssw0rd1                          |
    +-------------------------------------------------------------------+
    Are you sure you want to destroy the test lab? y

    You have 5 seconds to abort!

    5...4...3...2...1...BOOM!

    Destroy VAGRANT instance 'default' completed in 7.4898 seconds.

Destroy single or multiple containers:

    $ cucumber-chef destroy nginx-lb-test-1
    cucumber-chef v3.0.0.rc.0
    Are you sure you want to destroy the container 'nginx-lb-test-1'? y

    You have 5 seconds to abort!

    5...4...3...2...1...BOOM!

    Destroy container 'nginx-lb-test-1' completed in 24.4092 seconds.

## `cucumber-chef up`

Power up the cucumber-chef test lab:

    $ cucumber-chef up
    cucumber-chef v3.0.0.rc.0
    Booting VAGRANT instance 'default' completed in 37.2031 seconds.

## `cucumber-chef down`

Power off the cucumber-chef test lab:

    $ cucumber-chef down
    cucumber-chef v3.0.0.rc.0
    Downing VAGRANT instance 'default' completed in 31.1460 seconds.

## `cucumber-chef ssh [container]`

SSH to cucumber-chef test lab:

    $ cucumber-chef ssh
    cucumber-chef v3.0.0.rc.0
    Attempting SSH connection to the 'test lab'...
          _____                           _                _____ _           __
         / ____|                         | |              / ____| |         / _|
        | |    _   _  ___ _   _ _ __ ___ | |__   ___ _ __| |    | |__   ___| |_
        | |   | | | |/ __| | | | '_ ` _ \| '_ \ / _ \ '__| |    | '_ \ / _ \  _|
        | |___| |_| | (__| |_| | | | | | | |_) |  __/ |  | |____| | | |  __/ |
         \_____\__,_|\___|\__,_|_| |_| |_|_.__/ \___|_|   \_____|_| |_|\___|_|


        Welcome to the Cucumber Chef Test Lab v3.0.0.rc.0

    Last login: Fri Sep 14 06:23:18 2012 from 10.0.2.2
    vagrant@cucumber-chef:~$

SSH to a container:

    $ cucumber-chef ssh nginx-lb-test-1
    cucumber-chef v3.0.0.rc.0
    Attempting proxy SSH connection to the container 'nginx-lb-test-1'...
          _____                           _                _____ _           __
         / ____|                         | |              / ____| |         / _|
        | |    _   _  ___ _   _ _ __ ___ | |__   ___ _ __| |    | |__   ___| |_
        | |   | | | |/ __| | | | '_ ` _ \| '_ \ / _ \ '__| |    | '_ \ / _ \  _|
        | |___| |_| | (__| |_| | | | | | | |_) |  __/ |  | |____| | | |  __/ |
         \_____\__,_|\___|\__,_|_| |_| |_|_.__/ \___|_|   \_____|_| |_|\___|_|


        Welcome to the Cucumber Chef Test Lab v3.0.0.rc.0

        You are now logged in to the nginx-lb-test-1 container!

    root@nginx-lb-test-1:~#

## `cucumber-chef genmac`

Generate an RFC compliant private MAC address for use in a `Labfile`:

    $ cucumber-chef genmac
    cucumber-chef v3.0.0.rc.0
    00:00:5e:4f:96:b0

## `cucumber-chef genip`

Generate an RFC compliant private IP address for use in a `Labfile`:

    $ cucumber-chef genip
    cucumber-chef v3.0.0.rc.0
    192.168.244.120

## `cucumber-chef status`

Displays information on the status of the current test lab:

    $ cucumber-chef status
    cucumber-chef v3.0.0.rc.0
    +-------------------------------------------------------------------+
    |                      PROVIDER: Cucumber::Chef::Provider::Vagrant  |
    |                            ID: default                            |
    |                         STATE: running                            |
    |                      USERNAME: vagrant                            |
    |                    IP ADDRESS: 127.0.0.1                          |
    |                          PORT: 2222                               |
    |               CHEF-SERVER API: http://127.0.0.1:4000              |
    |             CHEF-SERVER WEBUI: http://127.0.0.1:4040              |
    |      CHEF-SERVER DEFAULT USER: admin                              |
    |  CHEF-SERVER DEFAULT PASSWORD: p@ssw0rd1                          |
    +-------------------------------------------------------------------+

Displays information on the status of the current test lab containers:

    $ cucumber-chef status --containers
    cucumber-chef v3.0.0.rc.0
    +----------------------+-------+--------+---------------+-------------------+---------------+---------+
    | NAME                 | ALIVE | DISTRO | IP            | MAC               | CHEF VERSION  | PERSIST |
    +----------------------+-------+--------+---------------+-------------------+---------------+---------+
    | nginx-lb-test-1      | true  | ubuntu | 192.168.0.100 | 00:00:5e:35:ea:d5 | Chef: 10.18.2 | true    |
    | nginx-unicorn-test-1 | true  | ubuntu | 192.168.0.200 | 00:00:5e:d1:fa:08 | Chef: 10.18.2 | true    |
    | redis-test-1         | true  | ubuntu | 192.168.0.210 | 00:00:5e:eb:8d:a3 | Chef: 10.18.2 | true    |
    | mysql-test-1         | true  | ubuntu | 192.168.0.220 | 00:00:5e:ea:fe:28 | Chef: 10.18.2 | true    |
    +----------------------+-------+--------+---------------+-------------------+---------------+---------+

## `cucumber-chef displayconfig`

Display various configuration information:

    $ cucumber-chef displayconfig
    cucumber-chef v3.0.0.rc.5
    --------------------------------------------------------------------------------
    ---
    :mode: :user
    :prerelease: true
    :user: zpatten
    :artifacts:
      chef-client-log: /var/log/chef/client.log
      chef-client-stacktrace: /var/chef/cache/chef-stacktrace.out
    :chef:
      :version: 10.24.0
      :default_password: p@ssw0rd1
      :render_client_rb: true
      :cookbook_paths:
      - cookbooks
      - site-cookbooks
    :test_lab:
      :hostname: cucumber-chef
      :tld: test-lab
    :command_timeout: 1800
    :provider: :vagrant
    :aws:
      :bootstrap_user: ubuntu
      :lab_user: cucumber-chef
      :lxc_user: root
      :ssh:
        :lab_port: 22
        :lxc_port: 22
      :ubuntu_release: precise
      :aws_instance_arch: i386
      :aws_instance_disk_store: ebs
      :aws_instance_type: c1.medium
      :aws_security_group: cucumber-chef
      :identity_file:
      :aws_access_key_id:
      :aws_secret_access_key:
      :aws_ssh_key_id:
      :region: us-west-2
      :availability_zone: us-west-2a
    :vagrant:
      :bootstrap_user: vagrant
      :lab_user: cucumber-chef
      :lxc_user: root
      :ssh:
        :lab_ip: 192.168.33.10
        :lab_port: 22
        :lxc_port: 22
      :cpus: 4
      :memory: 4096
      :identity_file: /home/zpatten/.vagrant.d/insecure_private_key

    --------------------------------------------------------------------------------
                   root_dir = "/home/zpatten/code/cc-chef-repo/vendor/checkouts/cucumber-chef"
                   home_dir = "/home/zpatten/code/cc-chef-repo/.cucumber-chef"
                   log_file = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/cucumber-chef.log"
              artifacts_dir = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/artifacts"
                  config_rb = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/config.rb"
                    labfile = "/home/zpatten/code/cc-chef-repo/Labfile"
                  chef_repo = "/home/zpatten/code/cc-chef-repo"
                  chef_user = "zpatten"
              chef_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/zpatten.pem"
             bootstrap_user = "vagrant"
    bootstrap_user_home_dir = "/home/vagrant"
         bootstrap_identity = "/home/zpatten/.vagrant.d/insecure_private_key"
                   lab_user = "cucumber-chef"
          lab_user_home_dir = "/home/cucumber-chef"
               lab_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/id_rsa-cucumber-chef"
                   lxc_user = "root"
          lxc_user_home_dir = "/root"
               lxc_identity = "/home/zpatten/code/cc-chef-repo/.cucumber-chef/vagrant/id_rsa-root"
                chef_pre_11 = true
    --------------------------------------------------------------------------------

# RESOURCES

Source:

* https://github.com/Atalanta/cucumber-chef

Issues:

* https://github.com/Atalanta/cucumber-chef/issues

Wiki:

* https://github.com/Atalanta/cucumber-chef/blob/master/WIKI.md

Forums:

* https://groups.google.com/d/forum/cucumber-chef

Chat:

* #cucumber-chef @ irc.freenode.net

# LICENSE

Cucumber-Chef - A test driven infrastructure system

* Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
* Author: Zachary Patten <zachary@jovelabs.com> [![endorse](http://api.coderwall.com/zpatten/endorsecount.png)](http://coderwall.com/zpatten)
* Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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

