module Cucumber
  module Chef
    class SSHError < Error ; end

    class SSH
      attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

      def self.ready?(ip)
        socket = TCPSocket.new(ip, 22)
        ((IO.select([socket], nil, nil, 5) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      ensure
        (socket && socket.close)
      end

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @config = {}
      end

      def exec(command)
        Net::SSH.start(@config[:hostname], @config[:user], options) do |ssh|
          channel = ssh.open_channel do |chan|
            chan.exec(command) do |ch, success|
              raise SSHError, "could not execute command" unless success

              ch.on_data do |c, data|
                @stdout.print(data)
                @stdout.flush
              end

              ch.on_extended_data do |c, type, data|
                @stderr.print(data)
                @stderr.flush
              end

            end
          end
          channel.wait
        end
      end

      def upload(local, remote)
        Net::SFTP.start(@config[:hostname], @config[:user], options) do |sftp|
          sftp.upload!(local.to_s, remote.to_s)
        end
      end


    private

      def proxy_command
        raise SSHError, "you must specify a key in order to proxy" if !@config[:key]

        command = ["ssh"]
        command << ["-o", "UserKnownHostsFile=/dev/null"]
        command << ["-o", "StrictHostKeyChecking=no"]
        command << ["-i", @config[:key]]
        command << "#{@config[:user]}@#{@config[:hostname]}"
        command << "nc %h %p"
        command.compact.join(" ")
      end

      def options
        options = {}.merge(:password => @config[:password]) if @config[:password]
        options = {}.merge(:keys => @config[:key]) if @config[:key]
        options = (options || {}).merge(:proxy => proxy_command) if @config[:proxy]

        options
      end

    end
  end
end
