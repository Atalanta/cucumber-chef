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

module Cucumber::Chef::Helpers::Server

################################################################################

  def log(name, ip, message)
    STDOUT.puts("\033[34m  * #{ip}: (LXC) '#{name}' #{message}\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)
  end

################################################################################

  def server_create(name, attributes={})
    if (attributes[:persist] && $servers[name])
      attributes = $servers[name]
    else
      container_destroy(name) if container_exists?(name)
      attributes = { :ip => generate_ip,
                     :mac => generate_mac,
                     :persist => true }.merge(attributes)
    end
    $servers = ($servers || Hash.new(nil)).merge(name => attributes)

    log(name, $servers[name][:ip], "Building") if $servers[name]

    test_lab_config_dhcpd
    container_config_network(name)
    container_create(name)
    Cucumber::Chef::TCPSocket.new($servers[name][:ip], 22).wait

    log(name, $servers[name][:ip], "Ready") if $servers[name]
  end

  def server_destroy(name)
    log(name, $servers[name][:ip], "Destroy") if $servers[name]

    container_destroy(name)
  end

################################################################################

  def servers
    containers
  end

################################################################################

end

################################################################################
