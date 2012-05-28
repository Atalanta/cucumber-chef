Description
===========

This cookbook is used to configure a Cucumber-Chef test lab.

Requirements
============

LXC 0.7.2 or higher is required.

Platforms
---------

The following platforms are supported by this cookbook:

* Debian
* Ubuntu

Recipes
=======

This section describes the recipes in the cookbook and how to use them in your environment.

lxc
---

Sets up Linux Containers for use by Cucumber-Chef.

test_lab
--------

Sets up the Cucumber-Chef test lab environment.

default
-------

Includes the `cucumber-chef::lxc` and `cucumber-chef::test_lab` recipes.

Roles
=====

This section describes the roles in the cookbook and how to use them in your environment.

test_lab
--------

Sets up the `default` recipe in the `run_list`.

Attributes
==========

Usage
=====

License and Author
==================

Author:: Zachary Patten (<zpatten@jovelabs.com>)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
