module Cucumber
  module Chef
    module Helpers

      require 'cucumber/chef/helpers/chef_client'
      require 'cucumber/chef/helpers/chef_server'
      require 'cucumber/chef/helpers/command'
      require 'cucumber/chef/helpers/container'
      require 'cucumber/chef/helpers/server'
      require 'cucumber/chef/helpers/test_lab'
      require 'cucumber/chef/helpers/utility'

      def self.included(base)
        base.send(:include, Cucumber::Chef::Helpers::ChefClient)
        base.send(:include, Cucumber::Chef::Helpers::ChefServer)
        base.send(:include, Cucumber::Chef::Helpers::Command)
        base.send(:include, Cucumber::Chef::Helpers::Container)
        base.send(:include, Cucumber::Chef::Helpers::Server)
        base.send(:include, Cucumber::Chef::Helpers::TestLab)
        base.send(:include, Cucumber::Chef::Helpers::Utility)
      end

    end
  end
end
