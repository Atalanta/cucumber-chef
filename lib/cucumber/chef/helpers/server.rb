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

  def server_create(name, attributes={})
    if ((attributes[:persist] && @servers[name]) || (@servers[name] && @servers[name][:persist]))
      attributes = @servers[name]
      log("using existing attributes for container $#{name} #{server_tag(name)}$")
    else
      if (container_exists?(name) && (ENV['DESTROY'] == "1"))
        server_destroy(name)
      end
      attributes = { :ip => generate_ip,
                     :mac => generate_mac,
                     :persist => true,
                     :distro => "ubuntu",
                     :release => "lucid",
                     :arch => detect_arch(attributes[:distro] || "ubuntu") }.merge(attributes)
    end
    @servers = (@servers || Hash.new(nil)).merge(name => attributes)
    $current_server = @servers[name][:ip]
    if !server_running?(name)
      log("please wait, creating container $#{name} #{server_tag(name)}$")
      bm = ::Benchmark.realtime do
        test_lab_config_dhcpd
        container_config_network(name)
        container_create(name, @servers[name][:distro], @servers[name][:release], @servers[name][:arch])
      end
      log("container $#{name}$ creation took %0.4f seconds" % bm)

      bm = ::Benchmark.realtime do
        ZTK::TCPSocketCheck.new(:host => @servers[name][:ip], :port => 22).wait
      end
      log("container $#{name}$ SSHD responded after %0.4f seconds" % bm)
    else
      log("container $#{name}$ is already running")
    end
  end

################################################################################

  def server_destroy(name)
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

  def server_tag(name)
    @servers[name].inspect.to_s
  end

################################################################################

  def detect_arch(distro)
    case distro.downcase
    when "ubuntu" then
      ((RUBY_PLATFORM =~ /x86_64/) ? "amd64" : "i386")
    when "fedora" then
      ((RUBY_PLATFORM =~ /x86_64/) ? "amd64" : "i686")
    end
  end

################################################################################

end

################################################################################
