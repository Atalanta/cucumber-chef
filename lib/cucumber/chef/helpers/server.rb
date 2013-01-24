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

module Cucumber::Chef::Helpers::Server

################################################################################

  def server_init(name)
    @containers[name] ||= Hash.new
  end

################################################################################

  def server_set_attributes(name, attributes={})
    @containers[name].merge!(attributes)
  end

################################################################################

  def server_create(name)
    attributes = (@containers[name] || {})
    if (@containers[name] && @containers[name][:persist])
      logger.info { "Using existing attributes for container {#{name.inspect} => #{server_tag(name)}}." }
    else
      attributes = { :ip => generate_ip,
                     :mac => generate_mac,
                     :persist => true,
                     :distro => "ubuntu",
                     :release => "lucid",
                     :arch => detect_arch(attributes[:distro] || "ubuntu") }.merge(attributes)
    end
    @containers[name] = attributes

    if server_running?(name)
      logger.info { "Container '#{name}' is already running." }
    else
      logger.info { "Please wait, creating container {#{name.inspect} => #{server_tag(name)}}." }
      bm = ::Benchmark.realtime do
        test_lab_config_dhcpd
        container_config_network(name)
        container_create(name, @containers[name][:distro], @containers[name][:release], @containers[name][:arch])
      end
      logger.info { "Container '#{name}' creation took %0.4f seconds." % bm }

      bm = ::Benchmark.realtime do
        ZTK::TCPSocketCheck.new(:host => @containers[name][:ip], :port => 22).wait
      end
      logger.info { "Container '#{name}' SSHD responded after %0.4f seconds." % bm }
    end

    save_containers
  end

################################################################################

  def server_destroy(name)
    container_destroy(name)
    @containers.delete(name)
    save_containers
  end

################################################################################

  def server_running?(name)
    container_running?(name)
  end

################################################################################

  # def servers
  #   containers
  # end

################################################################################

  def server_tag(name)
    @containers[name].inspect.to_s
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
