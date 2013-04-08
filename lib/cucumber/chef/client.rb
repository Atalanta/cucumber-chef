################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
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

    class ClientError < Error; end

    class Client
      attr_accessor :test_lab

################################################################################

      def initialize
        tag = Cucumber::Chef.tag("cucumber-chef")
        puts(">>> #{tag}")
        Cucumber::Chef.boot(tag)

        @ui = ZTK::UI.new(:logger => Cucumber::Chef.logger)

        if !((@test_lab = Cucumber::Chef::TestLab.new(@ui)) && @test_lab.alive?)
          message = "No running cucumber-chef test labs to connect to!"
          @ui.logger.fatal { message }
          raise message
        end

      end

################################################################################

      def up(options={})

        # PUSH CHEF-REPO
        #################

        # Upload all of the chef-repo environments
        ZTK::Benchmark.bench(:message => ">>> Pushing chef-repo environments to the test lab", :mark => "completed in %0.4f seconds.") do
          @test_lab.knife_cli(%(environment from file ./environments/*.rb), :silence => true)
        end

        # Upload all of the chef-repo cookbooks
        ZTK::Benchmark.bench(:message => ">>> Pushing chef-repo cookbooks to the test lab", :mark => "completed in %0.4f seconds.") do
          cookbook_paths = Cucumber::Chef::Config.chef[:cookbook_paths]
          @test_lab.knife_cli(%(cookbook upload --all --cookbook-path #{cookbook_paths.join(':')} --force), :silence => true)
        end

        # Upload all of the chef-repo roles
        ZTK::Benchmark.bench(:message => ">>> Pushing chef-repo roles to the test lab", :mark => "completed in %0.4f seconds.") do
          @test_lab.knife_cli(%(role from file ./roles/*.rb), :silence => true)
        end

        # Upload all of our chef-repo data bags
        Dir.glob("./data_bags/*").each do |data_bag_path|
          next if !File.directory?(data_bag_path)
          ZTK::Benchmark.bench(:message => ">>> Pushing chef-repo data bag '#{File.basename(data_bag_path)}' to the test lab", :mark => "completed in %0.4f seconds.") do
            data_bag = File.basename(data_bag_path)
            @test_lab.knife_cli(%(data bag create "#{data_bag}"), :silence => true)
            @test_lab.knife_cli(%(data bag from file "#{data_bag}" "#{data_bag_path}"), :silence => true)
          end
        end

        # PURGE CONTAINERS
        ###################
        if environment_variable_set?("PURGE")
          @ui.logger.warn { "PURGING CONTAINERS!  Container attributes will be reset!" }
          @test_lab.containers.list.each do |name|
            ZTK::Benchmark.bench(:message => ">>> Destroying container '#{name}'", :mark => "completed in %0.4f seconds.") do
              @test_lab.containers.destroy(name)
            end
          end
        else
          @ui.logger.info { "Allowing existing containers to persist." }
        end

        # CREATE CONTAINERS
        ####################
        Cucumber::Chef::Container.all.each do |container|
          ZTK::Benchmark.bench(:message => ">>> Creating container '#{container.id}'", :mark => "completed in %0.4f seconds.") do
            @test_lab.containers.create(container)
          end
        end

        # PROVISION CONTAINERS
        #######################
        @test_lab.containers.chef_set_client_config(:chef_server_url => "https://192.168.255.254",
                                                    :validation_client_name => "chef-validator")
        Cucumber::Chef::Container.all.each do |container|
          ZTK::Benchmark.bench(:message => ">>> Provisioning container '#{container.id}'", :mark => "completed in %0.4f seconds.") do
            @test_lab.containers.provision(container)
          end
        end

        true
      end

################################################################################

      def before(scenario)
        $scenario = scenario
      end

################################################################################

      def after(scenario)
      end

################################################################################

      def at_exit
      end

################################################################################
    private
################################################################################

      def environment_variable_set?(variable_name)
        raise "You must supply an environment variable name!" if variable_name.nil?

        variable_name = variable_name.strip.upcase

        (!ENV[variable_name].nil? && ((ENV[variable_name] == '1') || (ENV[variable_name].strip.upcase == 'YES')))
      end

    end

  end
end

################################################################################
