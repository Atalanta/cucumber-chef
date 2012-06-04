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
