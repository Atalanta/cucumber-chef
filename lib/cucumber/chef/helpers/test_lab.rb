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

module Cucumber::Chef::Helpers::TestLab

################################################################################

  def test_lab_config_dhcpd
    dhcpd_config = File.join("/etc/dhcp/test-lab.conf")
    File.open(dhcpd_config, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("DHCPD Configuration"))
      $servers.each do |key, value|
        f.puts
        f.puts("host #{key} {")
        f.puts("  hardware ethernet #{value[:mac]};")
        f.puts("  fixed-address #{value[:ip]};")
        f.puts("  ddns-hostname \"#{key}\";")
        f.puts("}")
      end
    end
    command_run_local("/etc/init.d/isc-dhcp-server restart")
  end

################################################################################

end

################################################################################
