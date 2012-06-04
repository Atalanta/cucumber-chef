################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber
  module Chef

    module Helpers

################################################################################

      require 'cucumber/chef/helpers/chef_client'
      require 'cucumber/chef/helpers/chef_server'
      require 'cucumber/chef/helpers/command'
      require 'cucumber/chef/helpers/container'
      require 'cucumber/chef/helpers/server'
      require 'cucumber/chef/helpers/test_lab'
      require 'cucumber/chef/helpers/utility'

################################################################################

      def self.included(base)
        base.send(:include, Cucumber::Chef::Helpers::ChefClient)
        base.send(:include, Cucumber::Chef::Helpers::ChefServer)
        base.send(:include, Cucumber::Chef::Helpers::Command)
        base.send(:include, Cucumber::Chef::Helpers::Container)
        base.send(:include, Cucumber::Chef::Helpers::Server)
        base.send(:include, Cucumber::Chef::Helpers::TestLab)
        base.send(:include, Cucumber::Chef::Helpers::Utility)
      end

################################################################################

    end

  end
end

################################################################################
