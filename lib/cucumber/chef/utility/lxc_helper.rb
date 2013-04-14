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
      module LXCHelper

        def lxc_user
          provider_config[:lxc_user]
        end

        def lxc_user_home_dir
          build_home_dir(provider_config[:lxc_user])
        end

        def lxc_identity
          lxc_identity = File.join(provider_dir, "id_rsa-#{lxc_user}")
          ensure_identity_permissions(lxc_identity)
          lxc_identity
        end

        def lxc_ip
          provider_config[:ssh][:lxc_ip]
        end

        def lxc_ssh_port
          provider_config[:ssh][:lxc_port]
        end

        def lxc_hostname_short
          Cucumber::Chef::Config.test_lxc[:hostname]
        end

        def lxc_hostname_full
          "#{lxc_hostname_short}.#{Cucumber::Chef::Config.test_lxc[:tld]}"
        end

      end
    end

  end
end
