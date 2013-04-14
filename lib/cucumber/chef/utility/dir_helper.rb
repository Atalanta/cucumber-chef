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
      module DirHelper

        def root_dir
          File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", ".."), File.dirname(__FILE__))
        end

        def home_dir
          result = (ENV['CUCUMBER_CHEF_HOME'] || File.join(Cucumber::Chef.locate_parent(".chef"), ".cucumber-chef"))
          ensure_directory(result)
          result
        end

        def provider_dir
          result = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s)
          ensure_directory(result)
          result
        end

        def artifacts_dir
          result = File.join(provider_dir, "artifacts")
          ensure_directory(result)
          result
        end

      end
    end

  end
end
