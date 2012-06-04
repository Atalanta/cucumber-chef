module Cucumber
  module Chef

    class SSHError < Error; end

    class SSH
      attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

      def self.ready?(host)
        socket = TCPSocket.new(host, 22)
        ((::IO.select([socket], nil, nil, 1) && socket.gets) ? true : false)
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      ensure
        (socket && socket.close)
      end

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @config = Hash.new(nil)
      end

      def console
        command = [ "ssh" ]
        command << [ "-q" ]
        command << [ "-o", "UserKnownHostsFile=/dev/null" ]
        command << [ "-o", "StrictHostKeyChecking=no" ]
        command << [ "-o", "KeepAlive=yes" ]
        command << [ "-o", "ServerAliveInterval=60" ]
        command << [ "-i", @config[:identity_file] ] if @config[:identity_file]
        command << [ "-o", "ProxyCommand='#{proxy_command}'" ] if @config[:proxy]
        command << "#{@config[:ssh_user]}@#{@config[:host]}"
        command = command.flatten.compact.join(" ")
        Kernel.exec(command)
      end

      def exec(command)
        Net::SSH.start(@config[:host], @config[:ssh_user], options) do |ssh|
          ssh.open_channel do |chan|
            $logger.debug { format("exec(#{command})", "SSH") }
            chan.exec(command) do |ch, success|
              raise SSHError, "Could not execute '#{command}'." unless success

              ch.on_data do |c, data|
                data = data.chomp
                @stdout.puts(data)
                $logger.debug { format(data, "STDOUT") }
              end

              ch.on_extended_data do |c, type, data|
                data = data.chomp
                @stderr.puts(data)
                $logger.debug { format(data, "STDERR") }
              end

            end
            chan.wait
          end
        end
      end

      def upload(local, remote)
        Net::SFTP.start(@config[:host], @config[:ssh_user], options) do |sftp|
          sftp.upload!(local.to_s, remote.to_s) do |event, uploader, *args|
            case event
            when :open
              $logger.debug { format("upload(#{args[0].local} -> #{args[0].remote})", "SFTP") }
            when :close
              $logger.debug { format("close(#{args[0].remote})", "SFTP") }
            when :mkdir
              $logger.debug { format("mkdir(#{args[0]})", "SFTP") }
            when :put
              $logger.debug { format("put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}", "SFTP") }
            when :finish
              $logger.debug { format("finish", "SFTP") }
            end
          end
        end
      end

      def download(remote, local)
        Net::SFTP.start(@config[:host], @config[:ssh_user], options) do |sftp|
          sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
            case event
            when :open
              $logger.debug { format("download(#{args[0].remote} -> #{args[0].local})", "SFTP") }
            when :close
              $logger.debug { format("close(#{args[0].local})", "SFTP") }
            when :mkdir
              $logger.debug { format("mkdir(#{args[0]})", "SFTP") }
            when :get
              $logger.debug { format("get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}", "SFTP") }
            when :finish
              $logger.debug { format("finish", "SFTP") }
            end
          end
        end
      end


    private

      def format(message, subsystem=nil)
        subsystem = [ "::", subsystem ].join if subsystem
        message = [ "[", @config[:host], subsystem, "]", " ", message ].join
        message
      end

      def proxy_command
        raise SSHError, "You must specify an identity file in order to SSH proxy." if !@config[:identity_file]

        command = ["ssh"]
        command << [ "-q" ]
        command << [ "-o", "UserKnownHostsFile=/dev/null" ]
        command << [ "-o", "StrictHostKeyChecking=no" ]
        command << [ "-o", "KeepAlive=yes" ]
        command << [ "-o", "ServerAliveInterval=60" ]
        command << [ "-i", @config[:proxy_identity_file] ] if @config[:proxy_identity_file]
        command << "#{@config[:proxy_ssh_user]}@#{@config[:proxy_host]}"
        command << "nc %h %p"
        command.flatten.compact.join(" ")
      end

      def options
        options = {}
        options.merge!(:password => @config[:ssh_password]) if @config[:ssh_password]
        options.merge!(:keys => @config[:identity_file]) if @config[:identity_file]
        options.merge!(:timeout => @config[:timeout]) if @config[:timeout]
        options.merge!(:user_known_hosts_file  => '/dev/null') if !@config[:host_key_verify]
        options.merge!(:proxy => proxy_command) if @config[:proxy]
        options
      end

    end

  end
end
