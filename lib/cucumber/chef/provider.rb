################################################################################
#
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

require 'cucumber/chef/providers/aws'
require 'cucumber/chef/providers/vagrant'

module Cucumber
  module Chef

    class ProviderError < Error; end

    class Provider
      PROXY_METHODS = %w(create destroy up down reload status id state username ip port alive? dead? exists?)

################################################################################

      def initialize(ui=ZTK::UI.new)
        @ui = ui

        @provider = case Cucumber::Chef::Config.provider
        when :aws then
          Cucumber::Chef::Provider::AWS.new(@ui)
        when :vagrant then
          Cucumber::Chef::Provider::Vagrant.new(@ui)
        end
      end

################################################################################

      def status
        if exists?

          headers = %w(provider id state username ip_address ssh_port).map(&:to_sym)
          results = ZTK::Report.new.list([nil], headers) do |noop|

            OpenStruct.new(
              :provider => @provider.class,
              :id => self.id,
              :state => self.state,
              :username => self.username,
              :ip_address => self.ip,
              :ssh_port => self.port
            )
          end
        else
          raise ProviderError, "No test labs exists!"
        end

      rescue Exception => e
        @ui.logger.fatal { e.message }
        @ui.logger.fatal { e.backtrace.join("\n") }
        raise ProviderError, e.message
      end

################################################################################

      def ip
        (Cucumber::Chef.lab_ip || @provider.ip)
      end

      def port
        (Cucumber::Chef.lab_ssh_port || @provider.port)
      end

################################################################################

      def method_missing(method_name, *method_args)
        if Cucumber::Chef::Provider::PROXY_METHODS.include?(method_name.to_s)
          result = @provider.send(method_name.to_sym, *method_args)
          splat = [method_name, *method_args].flatten.compact
          @ui.logger.debug { "Provider: #{splat.inspect}=#{result.inspect}" }
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
