################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber
  module Chef

    class TestRunnerError < Error; end

    class TestRunner

################################################################################

      def initialize(features_path, stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @features_path = features_path
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @test_lab = Cucumber::Chef::TestLab.new(@stdout, @stderr, @stdin)

        @ssh = Cucumber::Chef::SSH.new(@stdout, @stderr, @stdin)
        @ssh.config[:host] = @test_lab.labs_running.first.public_ip_address
        @ssh.config[:ssh_user] = "ubuntu"
        @ssh.config[:identity_file] = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{@ssh.config[:ssh_user]}")

        @stdout.puts("Cucumber-Chef Test Runner Initalized!")
      end

################################################################################

      def run(*args)
        reset_project
        upload_project

        @stdout.puts("Executing Cucumber-Chef Test Runner")
        remote_path = File.join("/", "home", "ubuntu", "features")
        cucumber_options = args.flatten.compact.uniq.join(" ")
        command = [ "cd #{remote_path} && sudo cucumber", cucumber_options, "." ].flatten.compact.join(" ")

        @ssh.exec(command)
      end


################################################################################
    private
################################################################################

      def reset_project
        @stdout.print("Cleaning up any previous test runs...")
        Cucumber::Chef.spinner do
          remote_path = File.join("/", "home", "ubuntu", "features")

          command = "rm -rf #{remote_path}"
          @ssh.exec(command, :silence => true)
        end
        @stdout.print("done.\n")
      end

################################################################################

      def upload_project
        @stdout.print("Uploading files required for this test run...")
        Cucumber::Chef.spinner do
          local_path = File.join(@features_path)
          remote_path = File.join("/", "home", "ubuntu", "features")
          @ssh.upload(local_path, remote_path)

          root_path = Cucumber::Chef.locate_parent(".chef")
          cucumber_config_file = File.expand_path(File.join(root_path, "cucumber.yml"))
          if File.exists?(cucumber_config_file)
            remote_file = File.join(remote_path, File.basename(cucumber_config_file))
            @ssh.upload(cucumber_config_file, remote_file)
          end
        end
        @stdout.print("done.\n")
      end

################################################################################

    end

  end
end

################################################################################
