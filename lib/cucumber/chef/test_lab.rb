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

    class TestLabError < Error; end

    class TestLab
      attr_accessor :provider, :containers

################################################################################

      def initialize(ui=ZTK::UI.new)
        @ui = ui

        @provider = Cucumber::Chef::Provider.new(@ui)
        @containers = Cucumber::Chef::Containers.new(@ui, self)
      end

################################################################################

      def bootstrap_ssh(options={})
        if (!defined?(@bootstrap_ssh) || @bootstrap_ssh.nil?)
          @bootstrap_ssh ||= ZTK::SSH.new({:ui => @ui, :timeout => Cucumber::Chef::Config.command_timeout}.merge(options))

          @bootstrap_ssh.config.host_name = self.ip
          @bootstrap_ssh.config.port = self.port
          @bootstrap_ssh.config.user = Cucumber::Chef.bootstrap_user
          @bootstrap_ssh.config.keys = Cucumber::Chef.bootstrap_identity
        end
        @bootstrap_ssh
      end

################################################################################

      def ssh(options={})
        if (!defined?(@ssh) || @ssh.nil?)
          @ssh ||= ZTK::SSH.new({:ui => @ui, :timeout => Cucumber::Chef::Config.command_timeout}.merge(options))

          @ssh.config.host_name = self.ip
          @ssh.config.port = self.port
          @ssh.config.user = Cucumber::Chef.lab_user
          @ssh.config.keys = Cucumber::Chef.lab_identity
        end
        @ssh
      end

################################################################################

      def proxy_ssh(container, options={})
        container = container.to_sym
        @proxy_ssh ||= Hash.new
        if (!defined?(@proxy_ssh[container]) || @proxy_ssh[container].nil?)
          @proxy_ssh[container] ||= ZTK::SSH.new({:ui => @ui, :timeout => Cucumber::Chef::Config.command_timeout}.merge(options))

          @proxy_ssh[container].config.proxy_host_name = self.ip
          @proxy_ssh[container].config.proxy_port = self.port
          @proxy_ssh[container].config.proxy_user = Cucumber::Chef.lab_user
          @proxy_ssh[container].config.proxy_keys = Cucumber::Chef.lab_identity

          @proxy_ssh[container].config.host_name = container
          @proxy_ssh[container].config.user = Cucumber::Chef.lxc_user
          @proxy_ssh[container].config.keys = Cucumber::Chef.lxc_identity
        end
        @proxy_ssh[container]
      end

################################################################################

      def knife_cli(args, options={})
        options = {:silence => true}.merge(options)

        arguments = Array.new
        arguments << "--user #{Cucumber::Chef::Config.user}"
        arguments << "--key #{Cucumber::Chef.chef_identity}"
        arguments << "--server-url #{self.chef_server_api}"
        arguments << "--disable-editing"
        arguments << "--yes"
        arguments << "-VV" if Cucumber::Chef.is_rc?

        command = Cucumber::Chef.build_command("knife", args, arguments)
        ZTK::Command.new.exec(command, options)
      end

################################################################################

      def method_missing(method_name, *method_args)
        if Cucumber::Chef::Provider::PROXY_METHODS.include?(method_name.to_s)
          result = @provider.send(method_name.to_sym, *method_args)
          splat = [method_name, *method_args].flatten.compact
          @ui.logger.debug { "TestLab: #{splat.inspect}=#{result.inspect}" }
          result
        else
          super(method_name, *method_args)
        end
      end

################################################################################

    end

  end
end

################################################################################
