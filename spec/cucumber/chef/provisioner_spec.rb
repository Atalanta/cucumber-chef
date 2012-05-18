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
    before(:all) do
      subject.upload_cookbook(@config)
      subject.upload_role(@config)
      sleep(5)
    end

    before(:each) do
      @test_lab = Cucumber::Chef::TestLab.new(@config)
      @test_lab.destroy
      begin
        buildoutput = StringIO.new
        server = subject.build_test_lab(@config, buildoutput)
      rescue
        puts "Output from #build_test_lab:"
        puts buildoutput.read
        raise
      end
      @dns_name = server.dns_name
      sleep(30)
    end

    after(:each) do
      @test_lab.destroy
    end

    it "should assign a random name to the node" do
      begin
        puts "Beginning bootstrap on #{@dns_name}..."
        subject.bootstrap_node(@dns_name, @config)
      rescue
        puts "Output from #bootstrap_node:"
        puts "  STANDARD OUTPUT:", subject.stdout.read, "\n\n"
        puts "  STANDARD ERROR:", subject.stderr.read, "\n\n"
        raise
      end
      found_node = false
      tries = 0
      while ! found_node && tries < 5
        tries += 1
        sleep(10)
        found_node = !!@test_lab.nodes.detect do |node|
          node.name.match /^cucumber-chef-[0-9a-f]{8}$/
        end
      end
      found_node.should be
    end
  end
end
