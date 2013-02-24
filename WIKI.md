[![Dependency Status](https://gemnasium.com/jovelabs/cucumber-chef.png)](https://gemnasium.com/jovelabs/cucumber-chef)

[![Build Status](https://secure.travis-ci.org/jovelabs/cucumber-chef.png)](http://travis-ci.org/jovelabs/cucumber-chef)

I was not particularly happy with the state of the 2.x documents and considering workflow changes, etc it made sense to me to start over with the documentation.  Since most things are the same the 2.x documentation will remain available in the repo as `WIKI.2.x.md`.  This is WIP.

# Cucumber-Chef 3.x Documentation

Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which Cucumber tests can be run which provision virtual machines, configure them by applying the appropriate Chef roles to them, and then run acceptance and integration tests against the environment.

# Prerequsites/Recommendations

Your `chef-repo` should be setup in a manner as follows:

* Use something like RVM for your ruby with your chef-repo
* Use something like bundler for your rubygems with your chef-repo
* Use something like berkshelf for your chef cookbooks with your chef-repo

If you do not use these patterns you will have an unplesant time in general.

# Workflow

When doing integration testing it makes sense that one generally wants to test across an entire ecosystem of servers.  You typically acquire a set of virtual or bare metal servers, provision those servers acordingly, put them into play then rinse and repeat.  I introduce the `Labfile`, the concept is simple if you haven't already guessed it.  You define a set of servers, i.e. an ecosystem, also dictating the settings and configuration.  Part of this change is because a) it makes alot of sense to me and b) it greatly decreases runtimes.  Also in cucumber-chef 2.x, we had insane background sections which bothered me tremendously and this change cleans up all of that mess as well.  The ultimate goal is to support configuration of multiple ecosystems, but we've got other ground to cover first so that feature will have to wait for a bit.  The `Labfile` should reside in the root of your `chef-repo`.

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

# Cucumber-Chef Tasks

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


# RESOURCES

Source:

* https://github.com/Atalanta/cucumber-chef

Issues:

* https://github.com/Atalanta/cucumber-chef/issues

Wiki:

* https://github.com/Atalanta/cucumber-chef/blob/master/WIKI.md

Chat:

* #cucumber-chef on irc.freenode.net

# LICENSE

Cucumber-Chef - A test driven infrastructure system

* Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
* Author: Zachary Patten <zachary@jovelabs.com>
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

