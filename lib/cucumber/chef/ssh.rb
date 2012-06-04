module Cucumber
  module Chef

    class SSHError < Error; end

    class SSH
      attr_accessor :stdout, :stderr, :stdin, :config

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @config = Hash.new(nil)
      end

################################################################################

      def console
        $logger.debug { "config(#{@config.inspect})" }

        command = [ "ssh" ]
        command << [ "-q" ]
        command << [ "-o", "UserKnownHostsFile=/dev/null" ]
        command << [ "-o", "StrictHostKeyChecking=no" ]
        command << [ "-o", "KeepAlive=yes" ]
        command << [ "-o", "ServerAliveInterval=60" ]
        command << [ "-i", @config[:identity_file] ] if @config[:identity_file]
        command << [ "-o", "ProxyCommand=\"#{proxy_command}\"" ] if @config[:proxy]
        command << "#{@config[:ssh_user]}@#{@config[:host]}"
        command = command.flatten.compact.join(" ")
        $logger.debug { "command(#{command})" }
        Kernel.exec(command)
      end

################################################################################

      def exec(command, options={})
        options = { :silence => false }.merge(options)
        silence = options[:silence]

        $logger.debug { "config(#{@config.inspect})" }
        $logger.debug { "options(#{options.inspect})" }
        $logger.info { "command(#{command})" }
        Net::SSH.start(@config[:host], @config[:ssh_user], ssh_options) do |ssh|
          ssh.open_channel do |chan|
            chan.exec(command) do |ch, success|
              raise SSHError, "Could not execute '#{command}'." unless success

              ch.on_data do |c, data|
                #data = data.chomp
                $logger.debug { data }
                @stdout.print(data) if !silence
              end

              ch.on_extended_data do |c, type, data|
                #data = data.chomp
                $logger.debug { data }
                @stderr.print(data) if !silence
              end

            end
          end
        end
      end

################################################################################

      def upload(local, remote)
        $logger.debug { "config(#{@config.inspect})" }
        $logger.info { "parameters(#{local},#{remote})" }
        Net::SFTP.start(@config[:host], @config[:ssh_user], ssh_options) do |sftp|
          sftp.upload!(local.to_s, remote.to_s) do |event, uploader, *args|
            case event
            when :open
              $logger.info { "upload(#{args[0].local} -> #{args[0].remote})" }
            when :close
              $logger.debug { "close(#{args[0].remote})" }
            when :mkdir
              $logger.debug { "mkdir(#{args[0]})" }
            when :put
              $logger.debug { "put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}" }
            when :finish
              $logger.info { "finish" }
            end
          end
        end
      end

################################################################################

      def download(remote, local)
        $logger.debug { "config(#{@config.inspect})" }
        $logger.info { "parameters(#{remote},#{local})" }
        Net::SFTP.start(@config[:host], @config[:ssh_user], ssh_options) do |sftp|
          sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
            case event
            when :open
              $logger.info { "download(#{args[0].remote} -> #{args[0].local})" }
            when :close
              $logger.debug { "close(#{args[0].local})" }
            when :mkdir
              $logger.debug { "mkdir(#{args[0]})" }
            when :get
              $logger.debug { "get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]}" }
            when :finish
              $logger.info { "finish" }
            end
          end
        end
      end


################################################################################
    private
################################################################################

      def proxy_command
        $logger.debug { "config(#{@config.inspect})" }

        if !@config[:identity_file]
          message = "You must specify an identity file in order to SSH proxy."
          $logger.fatal { message }
          raise SSHError, message
        end

        command = ["ssh"]
        command << [ "-q" ]
        command << [ "-o", "UserKnownHostsFile=/dev/null" ]
        command << [ "-o", "StrictHostKeyChecking=no" ]
        command << [ "-o", "KeepAlive=yes" ]
        command << [ "-o", "ServerAliveInterval=60" ]
        command << [ "-i", @config[:proxy_identity_file] ] if @config[:proxy_identity_file]
        command << "#{@config[:proxy_ssh_user]}@#{@config[:proxy_host]}"
        command << "nc %h %p"
        command = command.flatten.compact.join(" ")
        $logger.debug { "command(#{command})" }
        command
      end

################################################################################

      def ssh_options
        $logger.debug { "config(#{@config.inspect})" }
        options = {}
        options.merge!(:password => @config[:ssh_password]) if @config[:ssh_password]
        options.merge!(:keys => @config[:identity_file]) if @config[:identity_file]
        options.merge!(:timeout => @config[:timeout]) if @config[:timeout]
        options.merge!(:user_known_hosts_file  => '/dev/null') if !@config[:host_key_verify]
        options.merge!(:proxy => Net::SSH::Proxy::Command.new(proxy_command)) if @config[:proxy]
        $logger.debug { "options(#{options.inspect})" }
        options
      end

################################################################################

    end

  end
end
