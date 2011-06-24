require File.join(File.dirname(__FILE__), "../../spec_helper.rb")

describe Cucumber::Chef::Provisioner do
  before(:all) do
    @config = Cucumber::Chef::Config.test_config
  end

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
      subject.upload_cookbook(@config)
      ::Chef::CookbookVersion.list["cucumber-chef"].should be
    end
  end

  describe "upload_role" do
    before(:each) do
      begin
        role_path = File.expand_path("cookbooks/cucumber-chef/roles")
        ::Chef::Config[:role_path] = role_path
        role = ::Chef::Role.from_disk("test_lab_test")
        role.destroy
      rescue Net::HTTPServerException => err
      end
    end

    it "should upload the test_lab role" do
      subject.upload_role(@config)
      ::Chef::Role.list["test_lab_test"].should be
    end
  end

  describe "bootstrap_node" do
    before(:each) do
      @test_lab = Cucumber::Chef::TestLab.new(@config)
      @test_lab.destroy
      server = subject.build_test_lab(@config, StringIO.new)
      @dns_name = server.dns_name
      puts "Hanging around..." until tcp_test_ssh(server.public_ip_address)
      puts "Got ssh..."
      sleep(10)
      subject.upload_cookbook(@config)
      subject.upload_role(@config)
    end
    
    after(:each) do
      @test_lab.destroy
    end

    it "should assign a random name to the node" do
      subject.bootstrap_node(@dns_name, @config)
      @test_lab.nodes.detect do |node|
        node.name.match /^cucumber-chef-[0-9a-f]{8}$/
      end.should be
    end
  end

  describe "build_controller" do

    before(:each) do
      server = subject.build_test_lab(@config, StringIO.new)
      @dns_name = server.dns_name
      puts "Hanging around..." until tcp_test_ssh(server.public_ip_address)
      puts "Got ssh..."
      sleep(10)
      subject.upload_cookbook(@config)
      subject.upload_role(@config)
      subject.bootstrap_node(@dns_name, @config)
    end
    
    after(:each) do
      config = @config[:knife]
      connection = Fog::Compute.new(:provider => 'AWS',
                                    :aws_access_key_id => config[:aws_access_key_id],
                                    :aws_secret_access_key => config[:aws_secret_access_key],
                                    :region => config[:region])
      connection.servers.each do |s|
        s.destroy if s.tags['cucumber-chef'] == 'test' && s.state == 'running'
      end
    end

    it "should build a cucumber-chef controller" do
      controller_builder = subject.build_controller(@dns_name, @config)
      puts controller_builder.ui.stdout.string
    end
  end
end
