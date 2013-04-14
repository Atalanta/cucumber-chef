################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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

    module Utility
      module ChefHelper

        def chef_pre_11
          return false if (Cucumber::Chef::Config.chef[:version].downcase == "latest")
          (Cucumber::Chef::Config.chef[:version].to_f < 11.0)
        end

        def chef_repo
          (Cucumber::Chef.locate_parent(".chef") rescue nil)
        end

        def in_chef_repo?
          ((chef_repo && File.exists?(chef_repo) && File.directory?(chef_repo)) ? true : false)
        end

        def chef_user
          Cucumber::Chef::Config.user
        end

        def chef_identity
          result = File.join(provider_dir, "#{chef_user}.pem")
          ensure_directory(result)
          result
        end

      end
    end

  end
end
