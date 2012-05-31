maintainer        "Zachary Patten"
maintainer_email  "zpatten@jovelabs.com"
license           "Apache 2.0"
description       "Installs/Configures Cucumber-Chef"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "2.0.0"
recipe            "cucumber-chef", "Includes the lxc and test_lab recipes by default."
recipe            "cucumber-chef::lxc", "Sets up and configures LXC for use by the Cucumber-Chef Test Lab."
recipe            "cucumber-chef::test_lab", "Sets up the Cucumber-Chef Test Lab environment."

%w( ubuntu ).each do |os|
  supports os
end
