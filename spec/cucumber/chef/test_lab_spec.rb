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

describe Cucumber::Chef::TestLab do
  before(:all) do
    @config = Cucumber::Chef::Config.test_config(StringIO.new, StringIO.new, StringIO.new)
  end

  subject { Cucumber::Chef::TestLab.new(@config, StringIO.new, StringIO.new, StringIO.new) }

  it "should create a cucumber-chef security group" do
    existing_group = subject.connection.security_groups.get("cucumber-chef")
    existing_group && existing_group.destroy
    subject.connection.security_groups.get("cucumber-chef").should_not be
    lab = Cucumber::Chef::TestLab.new(@config, StringIO.new, StringIO.new, StringIO.new)
    permissions = lab.connection.security_groups.get("cucumber-chef").ip_permissions
    permissions.size.should == 1
    permissions.first["fromPort"].should == 22
    permissions.first["toPort"].should == 22
    permissions.first["fromPort"].should == 4000
    permissions.first["toPort"].should == 4000
    permissions.first["fromPort"].should == 4040
    permissions.first["toPort"].should == 4040
  end

  describe "with no running labs" do
    it "should not return any info" do
      subject.info
      subject.stdout.rewind
      subject.stdout.read.should match(/no test labs/)
    end
  end

  describe "create" do
    after(:each) { subject.destroy }

    it "should spin up an ec2 instance", :slow => true do
      subject.create
      subject.stdout.rewind
      subject.stdout.read.should match(/Instance provisioned/)
    end

    it "should attempt reprovision if ec2 instance already exists", :slow => true do
      subject.create
      subject.stdout.truncate(0)
      subject.create
      subject.stdout.rewind
      subject.stdout.read.should match(/attempting to reprovision/)
    end

    it "should report its public ip address", :slow => true do
      server = subject.create
      subject.info
      subject.stdout.rewind
      subject.stdout.read.should match(/#{server.public_ip_address}/)
    end
  end

  describe "destroy" do
    it "should destroy the running ec2 instance", :slow => true do
      server = subject.create
      subject.destroy
      subject.stdout.rewind
      subject.stdout.read.should match(/Destroying Server: #{server.public_ip_address}/)
    end
  end
end
=end
