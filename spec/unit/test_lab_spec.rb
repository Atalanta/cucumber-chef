require "rubygems"
require "bundler/setup"
require File.join(File.dirname(__FILE__), "../../lib/cucumber-chef")

describe Cucumber::Chef::TestLab do
  before(:all) do
    @config = Cucumber::Chef::Config.test_config
  end

  subject { Cucumber::Chef::TestLab.new(@config) }
    
  describe "build" do
    after(:each) { subject.destroy }

    it "should spin up an ec2 instance", :slow => true do
      output = StringIO.new
      subject.build(output)
      output.rewind
      output.read.should match(/Platform provisioned/)
    end

    it "should only spin up one ec2 instance", :slow => true do
      subject.build(StringIO.new)
      expect {
        subject.build(StringIO.new)
      }.to raise_error(Cucumber::Chef::TestLabError)
    end

  end

  describe "destroy" do
    it "should destroy the running ec2 instance", :slow => true do
      subject.build(StringIO.new)
      subject.destroy
      subject.exists?.should_not be
    end
  end

  describe "against a bootstrapped lab" do
    before(:each) do
      provisioner = Cucumber::Chef::Provisioner.new
      server = provisioner.build_test_lab(@config, StringIO.new)
      @dns_name = server.dns_name
      @public_ip_address = server.public_ip_address
      puts "Hanging around..." until tcp_test_ssh(server.public_ip_address)
      puts "Got ssh..."
      sleep(10)
      provisioner.upload_cookbook(@config)
      provisioner.upload_role(@config)
      provisioner.bootstrap_node(@dns_name, @config).run
    end

    after(:each) { subject.destroy }

    it "should report its public ip address", :slow => true do
      subject.info.should match(/#{@public_ip_address}/)
    end
  end
end

