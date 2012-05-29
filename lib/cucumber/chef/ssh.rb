module Cucumber
  module Chef
    class SSHError < Error ; end

    class SSH
      attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

      def self.ready?(host)
        socket = TCPSocket.new(host, 22)
        ((IO.select([socket], nil, nil, 5) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      ensure
        (socket && socket.close)
      end

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @config = Hash.new(nil)
      end

      def exec(command)
        Net::SSH.start(@config[:host], @config[:ssh_user], options) do |ssh|
          channel = ssh.open_channel do |chan|
            chan.exec(command) do |ch, success|
              raise SSHError, "could not execute command" unless success

              ch.on_data do |c, data|
                @stdout.print("#{@config[:host]} #{data}")
                @stdout.flush
              end

              ch.on_extended_data do |c, type, data|
                @stderr.print("#{@config[:host]} #{data}")
                @stderr.flush
              end

            end
          end
          channel.wait
        end
      end

      def upload(local, remote)
        Net::SFTP.start(@config[:host], @config[:ssh_user], options) do |sftp|
          sftp.upload!(local.to_s, remote.to_s)
        end
      end


    private

      def proxy_command
        raise SSHError, "you must specify an identity file in order to proxy" if !@config[:identity_file]

        command = ["ssh"]
        command << ["-o", "UserKnownHostsFile=/dev/null"]
        command << ["-o", "StrictHostKeyChecking=no"]
        command << ["-i", @config[:identity_file]]
        command << "#{@config[:ssh_user]}@#{@config[:host]}"
        command << "nc %h %p"
        command.compact.join(" ")
      end

      def options
        options = (options || {}).merge(:password => @config[:ssh_password]) if @config[:ssh_password]
        options = (options || {}).merge(:keys => @config[:identity_file]) if @config[:identity_file]
        options = (options || {}).merge(:user_known_hosts_file  => '/dev/null') if !@config[:host_key_verify]
        options = (options || {}).merge(:proxy => proxy_command) if @config[:proxy]

        options
      end

    end
  end
end
