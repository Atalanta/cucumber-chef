################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
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

require 'spec_helper'
=begin
require File.join(File.dirname(__FILE__), "../../spec_helper.rb")

describe Cucumber::Chef::Provisioner do
  before(:all) do
    @config = Cucumber::Chef::Config.test_config(StringIO.new, StringIO.new, StringIO.new)
  end

  subject { Cucumber::Chef::Provisioner.new(@config, StringIO.new, StringIO.new, StringIO.new) }

  describe "upload_cookbook" do
    before(:each) do
      begin
        cookbook_path = File.expand_path("cookbooks/cucumber-chef")
        version_loader = ::Chef::Cookbook::CookbookVersionLoader.new(cookbook_path)
        version_loader.load_cookbooks
        version = version_loader.cookbook_version
        version.destroy
      rescue Net::HTTPServerException => err
      end
    end

    it "should upload the cucumber-chef cookbook" do
      subject.upload_cookbook
      ::Chef::CookbookVersion.list["cucumber-chef"].should be
    end
  end

  describe "upload_role" do
    before(:each) do
      begin
        role_path = File.expand_path("cookbooks/cucumber-chef/roles")
        ::Chef::Config[:role_path] = role_path
        role = ::Chef::Role.from_disk("test_lab")
        role.destroy
      rescue Net::HTTPServerException => err
      end
    end

    it "should upload the test_lab role" do
      subject.upload_role
      ::Chef::Role.list["test_lab"].should be
    end
  end

  describe "bootstrap_node" do
    before(:all) do
      subject.upload_cookbook
      subject.upload_role
    end

    before(:each) do
      @test_lab = Cucumber::Chef::TestLab.new(@config, StringIO.new, StringIO.new, StringIO.new)
      @test_lab.destroy
      begin
        @server = @test_lab.create
      rescue
        puts("Output from #create:")
        subject.stdout.rewind
        puts(subject.stdout.read)
        raise
      end
    end

    after(:each) do
      @test_lab.destroy
    end

    it "should assign a random name to the node", :slow => true do
      begin
        subject.bootstrap_node(@server)
      rescue
        subject.stdout.rewind; subject.stderr.rewind
        puts("Output from #bootstrap_node:")
        puts("  STDOUT:\n", subject.stdout.read, "\n\n")
        puts("  STDERR:\n", subject.stderr.read, "\n\n")
        raise
      end
      sleep(30)
      found_node = !!@test_lab.nodes.detect do |node|
        node.name.match /^cucumber-chef-[0-9a-f]{8}$/
      end
      found_node.should be
    end
  end
end
=end
