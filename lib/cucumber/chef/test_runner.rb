module Cucumber
  module Chef

    class TestRunnerError < Error; end

    class TestRunner

      def initialize(project_dir, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @project_dir = project_dir
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @test_lab = Cucumber::Chef::TestLab.new(@stdout, @stderr, @stdin)

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @ssh.config[:host] = @test_lab.labs_running.first.public_ip_address
        @ssh.config[:ssh_user] = "ubuntu"
        @ssh.config[:identity_file] = Cucumber::Chef::Config[:aws][:identity_file]

        @stdout.puts("Cucumber-Chef Test Runner Initalized!")
      end

      def run(*args)
        reset_project
        upload_project

        remote_path = File.join("/", "home", "ubuntu", "cucumber-chef", File.basename(@project_dir), "features")
        cucumber_options = args.flatten.compact.uniq.join(" ")
        command = [ "sudo cucumber", cucumber_options, remote_path ].flatten.compact.join(" ")

        @ssh.exec(command)
      end


    private

      def reset_project
        remote_path = File.join("/", "home", "ubuntu", "cucumber-chef")

        command = "rm -rf #{remote_path}"
        @ssh.exec(command)

        command = "mkdir -p #{remote_path}"
        @ssh.exec(command)
      end

      def upload_project
        config_path = Cucumber::Chef.locate(:directory, ".cucumber-chef")
        cucumber_config_file = File.expand_path(File.join(config_path, "cucumber.yml"))
        if File.exists?(cucumber_config_file)
          remote_file = File.join("/", "home", "ubuntu", File.basename(cucumber_config_file))
          @ssh.upload(cucumber_config_file, remote_file)
        end

        local_path = @project_dir
        remote_path = File.join("/", "home", "ubuntu", "cucumber-chef", File.basename(@project_dir))
        @ssh.upload(local_path, remote_path)
      end

    end

  end
end
