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

module Cucumber
  module Chef

    class TCPSocketError < Error; end

    class TCPSocket

################################################################################

      def initialize(host, port)
        @host, @port = host, port

        if !host
          message = "You must supply a host!"
          $logger.fatal { message }
          raise TCPSocketError, message
        end

        if !port
          message = "You must supply a port!"
          $logger.fatal { message }
          raise TCPSocketError, message
        end
      end

################################################################################

      def ready?
        socket = ::TCPSocket.new(@host, @port)
        ((::IO.select([socket], nil, nil, 5) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      ensure
        (socket && socket.close)
      end

################################################################################

      def wait
        begin
          success = ready?
          sleep(1)
        end until success
      end

################################################################################

    end

  end
end

################################################################################
