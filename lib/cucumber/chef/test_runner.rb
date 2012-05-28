module Cucumber
  module Chef
    class TestRunnerError < Error ; end

    class TestRunner

      require 'cucumber/chef/test_lab'

      def initialize(project_dir, config)
        @project_dir = project_dir
        @config = config

        @test_lab = Cucumber::Chef::TestLab.new(@config)
        @hostname = @test_lab.labs_running.first.public_ip_address
        @key = File.expand_path(@config[:knife][:identity_file])

        puts("Cucumber-Chef Test Runner Initalized!")
      end

################################################################################

      def run
        reset_project
        upload_project
        project_path = File.join('/home/ubuntu', File.basename(@project_dir), 'features')
        ssh_exec_async("sudo cucumber -c -v -b #{project_path}")
      end

      def reset_project
        project_base_path = File.join('/home/ubuntu', File.basename(@project_dir))
        ssh_exec_async("rm -rf #{project_base_path}")
      end

      def upload_project
        sftp(@project_dir, File.join('/home/ubuntu', File.basename(@project_dir)))
      end

################################################################################

      def ssh_exec_async(command)
        puts("  * #{@hostname}: (SSH) '#{command}'")
        Net::SSH.start(@hostname, "ubuntu", :keys => @key) do |ssh|
          channel = ssh.open_channel do |chan|
            chan.exec(command) do |ch, success|
              raise "could not execute command" unless success

              ch.on_data do |c, data|
                STDOUT.print(data)
                STDOUT.flush
              end

              ch.on_extended_data do |c, type, data|
                STDERR.print(data)
                STDERR.flush
              end

            end
          end
          channel.wait
        end
      end

      def sftp(local, remote)
        puts("  * #{@hostname}: (SCP) '#{local}' -> '#{remote}'")
        Net::SFTP.start(@hostname, "ubuntu", :keys => @key) do |sftp|
          sftp.upload!(local.to_s, remote.to_s)
        end
      end

################################################################################

      def ssh_exec_async_via_proxy(user, host, command)
        puts("  * Proxy via #{@hostname} to #{host}: (SSH) '#{command}'")
        proxy = Net::SSH::Proxy::Command.new("ssh -i #{@key} ubuntu@#{@hostname} nc %h %p")
        Net::SSH.start(host, user, :keys => @key, :proxy => proxy) do |ssh|
          channel = ssh.open_channel do |chan|
            chan.exec(command) do |ch, success|
              raise "could not execute command" unless success

              ch.on_data do |c, data|
                STDOUT.print(data)
                STDOUT.flush
              end

              ch.on_extended_data do |c, type, data|
                STDERR.print(data)
                STDERR.flush
              end

            end
          end
          channel.wait
        end
      end

      def sftp_via_proxy(user, host, local, remote)
        puts("  * Proxy via #{@hostname} to #{host}: (SCP) '#{local}' -> '#{remote}'")
        proxy = Net::SSH::Proxy::Command.new("ssh -i #{@key} ubuntu@#{@hostname} nc %h %p")
        Net::SFTP.start(host, user, :keys => @key, :proxy => proxy) do |sftp|
          sftp.upload!(local.to_s, remote.to_s)
        end
      end

    end
  end
end
