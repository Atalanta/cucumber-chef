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

module Cucumber
  module Chef
    class Provider

      class VagrantError < Error; end

      class Vagrant
        attr_accessor :stdout, :stderr, :stdin, :logger

################################################################################

        def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
          @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
          @stdout.sync = true if @stdout.respond_to?(:sync=)
        end

################################################################################

        def create
          raise "Not Implemented!"

          self
        end

        def destroy
          raise "Not Implemented!"
        end

        def start
          raise "Not Implemented!"
        end

        def stop
          raise "Not Implemented!"
        end

        def info
          raise "Not Implemented!"
        end

        def labs_exists?
          raise "Not Implemented!"
        end

        def labs
          raise "Not Implemented!"
        end

        def labs_running
          raise "Not Implemented!"
        end

        def labs_shutdown
          raise "Not Implemented!"
        end

        def public_ip
          raise "Not Implemented!"
        end

        def private_ip
          raise "Not Implemented!"
        end

      end

    end
  end
end

################################################################################
