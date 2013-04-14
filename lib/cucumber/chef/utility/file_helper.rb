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
      module FileHelper

        def log_file
          result = File.join(Cucumber::Chef.home_dir, "cucumber-chef.log")
          ensure_directory(result)
          result
        end

        def config_rb
          result = File.join(Cucumber::Chef.home_dir, "config.rb")
          ensure_directory(result)
          result
        end

        def labfile
          result = File.join(Cucumber::Chef.chef_repo, "Labfile")
          ensure_directory(result)
          result
        end

        # def knife_rb
        #   knife_rb = File.join(provider_dir, "knife.rb")
        #   FileUtils.mkdir_p(File.dirname(knife_rb))
        #   knife_rb
        # end

      end
    end

  end
end
