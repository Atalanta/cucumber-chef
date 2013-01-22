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
      attr_accessor :stdout, :stderr, :stdin, :logger

      PROXY_METHODS = %w(create destroy start stop info lab_exists? labs labs_running labs_shutdown public_ip private_ip ssh_port)

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
        @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @provider = case Cucumber::Chef::Config[:provider]
        when :aws then
          Cucumber::Chef::Provider::AWS.new(@stdout, @stderr, @stdin, @logger)
        when :vagrant then
          nil
        end
      end

################################################################################

      def method_missing(method_name, *method_args)
        if Cucumber::Chef::Provider::PROXY_METHODS.include?(method_name.to_s)
          Cucumber::Chef.logger.debug { "provider: #{method_name} #{method_args.inspect}" }
          @provider.send(method_name.to_sym, *method_args)
        else
          super(method_name, *method_args)
        end
      end

################################################################################

    end

  end
end

################################################################################
