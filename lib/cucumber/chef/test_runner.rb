module Cucumber
  module Chef

    class TestRunnerError < Error; end

    class TestRunner

      require 'cucumber/chef/test_lab'

      def initialize(config, project_dir, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @config = config
        @project_dir = project_dir
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @test_lab = Cucumber::Chef::TestLab.new(@config)

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @ssh.config[:hostname] = @test_lab.labs_running.first.public_ip_address
        @ssh.config[:ssh_user] = "ubuntu"
        @ssh.config[:identity_file] = File.expand_path(@config[:knife][:identity_file])

        puts("Cucumber-Chef Test Runner Initalized!")
      end

      def run
        reset_project
        upload_project
        project_path = File.join('/home/ubuntu', File.basename(@project_dir), 'features')
        command = "sudo cucumber -c -v -b #{project_path}"
        @ssh.exec(command)
      end


    private

      def reset_project
        project_base_path = File.join('/home/ubuntu', File.basename(@project_dir))
        command = "rm -rf #{project_base_path}"
        @ssh.exec(command)
      end

      def upload_project
        local = @project_dir
        remote = File.join('/home/ubuntu', File.basename(@project_dir))
        @ssh.upload(local, remote)
      end

    end

  end
end
