################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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

  def log(name, message)
    STDOUT.puts("\033[34m====> \033[1m#{name}\033[0m\033[34m #{message}\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)
  end

################################################################################

  def detect_arch(distro)
    case distro.downcase
    when "ubuntu":
      ((RUBY_PLATFORM =~ /x86_64/) ? "amd64" : "i386")
    when "fedora":
      ((RUBY_PLATFORM =~ /x86_64/) ? "amd64" : "i686")
    end
  end

  def server_create(name, attributes={})
    if ((attributes[:persist] && $servers[name]) || ($servers[name] && $servers[name][:persist]))
      attributes = $servers[name]
    else
      server_destroy(name) if container_exists?(name)
      attributes = { :ip => generate_ip,
                     :mac => generate_mac,
                     :persist => true,
                     :distro => "ubuntu",
                     :release => "lucid",
                     :arch => detect_arch(attributes[:distro] || "ubuntu") }.merge(attributes)
    end
    $servers = ($servers || Hash.new(nil)).merge(name => attributes)
    $current_server = $servers[name][:ip]
    if !server_running?(name)
      log(name, "is being provisioned") if $servers[name]

      test_lab_config_dhcpd
      container_config_network(name)
      container_create(name, $servers[name][:distro], $servers[name][:release], $servers[name][:arch])
      Cucumber::Chef::TCPSocket.new($servers[name][:ip], 22).wait
    end
  end

  def server_destroy(name)
    log(name, "is being destroyed") if $servers[name]

    container_destroy(name)
  end

################################################################################

  def server_running?(name)
    container_running?(name)
  end

################################################################################

  def servers
    containers
  end

################################################################################

end

################################################################################
