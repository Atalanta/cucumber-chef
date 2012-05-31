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
            chan.exec(command) do |ch, success|
              raise SSHError, "Could not execute '#{command}'." unless success

              ch.on_data do |c, data|
                @stdout.puts("[#{@config[:host]}::STDOUT] #{data}")
              end

              ch.on_extended_data do |c, type, data|
                @stderr.puts("[#{@config[:host]}::STDERR] #{data}")
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
              @stdout.puts("[#{@config[:host]}] upload(#{args[0].local} -> #{args[0].remote})")
            when :close
              @stdout.puts("[#{@config[:host]}] close(#{args[0].remote})")
            when :mkdir
              @stdout.puts("[#{@config[:host]}] mkdir(#{args[0]})")
            when :put
              @stdout.puts("[#{@config[:host]}] put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}")
            when :finish
              @stdout.puts("[#{@config[:host]}] finish")
            end
          end
        end
      end

      def download(remote, local)
        Net::SFTP.start(@config[:host], @config[:ssh_user], options) do |sftp|
          sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
            case event
            when :open
              @stdout.puts("[#{@config[:host]}] download(#{args[0].remote} -> #{args[0].local})")
            when :close
              @stdout.puts("[#{@config[:host]}] close(#{args[0].local})")
            when :mkdir
              @stdout.puts("[#{@config[:host]}] mkdir(#{args[0]})")
            when :get
              @stdout.puts("[#{@config[:host]}] get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}")
            when :finish
              @stdout.puts("[#{@config[:host]}] finish")
            end
          end
        end
      end


    private

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
