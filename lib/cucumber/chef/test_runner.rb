module Cucumber
  module Chef
    class TestRunnerError < Error ; end

    class TestRunner

      require 'cucumber/chef/test_lab'

      def initialize(project_dir, config)
        @project_dir = project_dir
        @config = config
      end

      def run
        reset_project
        upload_project
        @project_path = File.join('/home/ubuntu', File.basename(@project_dir), 'features')
        connection = Net::SSH.start(@hostname, 'ubuntu', :keys => @key) do |ssh|
          channel = ssh.open_channel do |chan|
            chan.exec("sudo cucumber -c -v #{@project_path}") do |ch, success|
              raise "could not execute command" unless success

              ch.on_data do |c, data|
                STDOUT.print(data)
                STDOUT.flush
              end

              ch.on_extended_data do |c, type, data|
                STDERR.print(data)
                STDERR.flush
              end

              ch.on_close { puts "done" }
            end
          end
          channel.wait
        end
      end

      def reset_project
        test_lab = Cucumber::Chef::TestLab.new(@config)
        @hostname = test_lab.labs_running.first.public_ip_address
        @key = File.expand_path(@config[:knife][:identity_file])
        %x[ssh -i #{@key} ubuntu@#{@hostname} "rm -rf #{@project_dir}"]
        puts "Cucumber-chef project: #{File.basename(@project_dir)} sucessfully reset on the test lab."
      end

      def upload_project
        test_lab = Cucumber::Chef::TestLab.new(@config)
        @hostname = test_lab.labs_running.first.public_ip_address
        @key = File.expand_path(@config[:knife][:identity_file])
        %x[scp -r -i #{@key} #{@project_dir} ubuntu@#{@hostname}:]
        puts "Cucumber-chef project: #{File.basename(@project_dir)} sucessfully uploaded to the test lab."
      end
    end
  end
end
