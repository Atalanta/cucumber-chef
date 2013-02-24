[![Build Status](https://secure.travis-ci.org/jovelabs/cucumber-chef.png)](http://travis-ci.org/jovelabs/cucumber-chef) [![Dependency Status](https://gemnasium.com/jovelabs/cucumber-chef.png)](https://gemnasium.com/jovelabs/cucumber-chef)

I was not particularly happen with the state of the 2.x documents and considering workflow changes, etc it made sense to me to start over with the documentation.  Since most things are the same the 2.x documentation will remain available in the repo as `WIKI.2.x.md`.

# Cucumber-Chef 3.x Documentation

Cucumber-chef is a library of tools to enable the emerging discipline of infrastructure as code to practice test driven development.  It provides a testing platform within which Cucumber tests can be run which provision virtual machines, configure them by applying the appropriate Chef roles to them, and then run acceptance and integration tests against the environment.

# Workflow

When doing integration testing it makes sense that one generally wants to test across an entire ecosystem of servers.  You typically acquire a set of virtual or bare metal servers, provision those servers acordingly, put them into play then rinse and repeat.  I introduce the `Labfile`, the concept is simple if you haven't already guessed it.  You define a set of servers, i.e. an ecosystem, also dictating the settings and configuration.  Part of this change is because a) it makes alot of sense to me and b) it greatly decreases runtimes.  Also in cucumber-chef 2.x, we had insane background sections which bothered me tremendously and this change cleans up all of that mess as well.  The ultimate goal is to support configuration of multiple ecosystems, but we've got other ground to cover first so that feature will have to wait for a bit.

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
        ip "192.168.32.210"
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

