module Cucumber
  module Chef

    class SSHError < Error; end

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
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @config = Hash.new(nil)
        @config[:formatter] = true
      end

      def console
        options = [ "ssh" ]
        options << [ "-i", @config[:identity_file] ] if @config[:identity_file]
        options << [ "-o", "UserKnownHostsFile=/dev/null" ]
        options << [ "-o", "StrictHostKeyChecking=no" ]
        options << "#{@config[:ssh_user]}@#{@config[:host]}"

        Kernel.exec(*(options.flatten.compact))
      end

      def exec(command)
        Net::SSH.start(@config[:host], @config[:ssh_user], options) do |ssh|
          ssh.open_channel do |chan|
            @stdout.puts(format("exec(#{command})", "SSH", true))
            chan.exec(command) do |ch, success|
              raise SSHError, "Could not execute '#{command}'." unless success

              ch.on_data do |c, data|
                @stdout.puts(format(data, "STDOUT"))
              end

              ch.on_extended_data do |c, type, data|
                @stderr.puts(format(data, "STDERR"))
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
              @stdout.puts(format("upload(#{args[0].local} -> #{args[0].remote})", "SFTP"))
            when :close
              @stdout.puts(format("close(#{args[0].remote})", "SFTP"))
            when :mkdir
              @stdout.puts(format("mkdir(#{args[0]})", "SFTP"))
            when :put
              @stdout.puts(format("put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}", "SFTP"))
            when :finish
              @stdout.puts(format("finish", "SFTP"))
            end
          end
        end
      end

      def download(remote, local)
        Net::SFTP.start(@config[:host], @config[:ssh_user], options) do |sftp|
          sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
            case event
            when :open
              @stdout.puts(format("download(#{args[0].remote} -> #{args[0].local})", "SFTP"))
            when :close
              @stdout.puts(format("close(#{args[0].local})", "SFTP"))
            when :mkdir
              @stdout.puts(format("mkdir(#{args[0]})", "SFTP"))
            when :get
              @stdout.puts(format("get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}", "SFTP"))
            when :finish
              @stdout.puts(format("finish", "SFTP"))
            end
          end
        end
      end


    private

      def format(message, subsystem=nil, force=false)
        subsystem = [ "::", subsystem ].join if subsystem
        message = [ "[", @config[:host], subsystem, "]", " ", message ].join if (force || @config[:formatter])
        message
      end

      def proxy_command
        raise SSHError, "You must specify an identity file in order to SSH proxy." if !@config[:identity_file]

        command = ["ssh"]
        command << ["-o", "UserKnownHostsFile=/dev/null"]
        command << ["-o", "StrictHostKeyChecking=no"]
        command << ["-i", @config[:identity_file]]
        command << "#{@config[:ssh_user]}@#{@config[:host]}"
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
