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
      module LabHelper

        def lab_user
          provider_config[:lab_user]
        end

        def lab_user_home_dir
          build_home_dir(provider_config[:lab_user])
        end

        def lab_identity
          lab_identity = File.join(provider_dir, "id_rsa-#{lab_user}")
          ensure_identity_permissions(lab_identity)
          lab_identity
        end

        def lab_ip
          provider_config[:ssh][:lab_ip]
        end

        def lab_ssh_port
          provider_config[:ssh][:lab_port]
        end

        def lab_hostname_short
          Cucumber::Chef::Config.test_lab[:hostname]
        end

        def lab_hostname_full
          "#{lab_hostname_short}.#{Cucumber::Chef::Config.test_lab[:tld]}"
        end

      end
    end

  end
end
