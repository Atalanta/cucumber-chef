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
        upload_project
        @project_path = File.join('/home/ubuntu', File.basename(@project_dir), 'features')
        connection = Net::SSH.start(@hostname, 'ubuntu', :keys => @key) do |ssh|
          @output = ssh.exec!("sudo cucumber -c -v #{@project_path}")
        end
        puts @output
      end

      def upload_project
        lab = Cucumber::Chef::TestLab.new(@config)
        @hostname = lab.public_hostname
        @key = File.expand_path(@config[:knife][:identity_file])
        %x[scp -r -i #{@key} #{@project_dir} ubuntu@#{@hostname}:]
        puts "Cucumber-chef project: #{File.basename(@project_dir)} sucessfully uploaded to the test lab."
      end
    end
  end
end
