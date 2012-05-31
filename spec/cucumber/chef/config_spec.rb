require 'spec_helper'

VALID_RELEASES = %w(maverick)
VALID_REGIONS = %w(us-west-1 us-east-1 eu-west-1)
VALID_ARCHS = %w(i386 amd64)
VALID_DISK_STORES = %w(instance-store ebs)

describe Cucumber::Chef::Config do

#  before(:all) do
#    @original_config = Cucumber::Chef::Config.hash_dup
#    Cucumber::Chef::Config.mode = :test
#  end

#  after(:each) do
#    Cucumber::Chef::Config.configuration = @original_config
#  end

  before(:each) do
    load File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "config.rb"))
  end

  after(:each) do
    load File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper.rb"))
  end

  describe "Cucumber::Chef::Config default values" do

    it "Cucumber::Chef::Config[:mode] defaults to :user" do
      Cucumber::Chef::Config[:mode].should == :user
    end

    it "Cucumber::Chef::Config[:provider] defaults to :aws" do
      Cucumber::Chef::Config[:provider].should == :aws
    end

    context "Cucumber::Chef::Config[:aws] default values" do

      it "Cucumber::Chef::Config[:aws][:security_group] defaults to 'cucumber-chef'" do
        Cucumber::Chef::Config[:aws][:security_group].should == "cucumber-chef"
      end

      it "Cucumber::Chef::Config[:aws][:ubuntu_release] defaults to 'maverick'" do
        Cucumber::Chef::Config[:aws][:ubuntu_release].should == "maverick"
      end

      it "Cucumber::Chef::Config[:aws][:aws_instance_arch] defaults to 'i386'" do
        Cucumber::Chef::Config[:aws][:aws_instance_arch].should == "i386"
      end

      it "Cucumber::Chef::Config[:aws][:aws_instance_disk_store] defaults to 'instance-store'" do
        Cucumber::Chef::Config[:aws][:aws_instance_disk_store].should == "instance-store"
      end

      it "Cucumber::Chef::Config[:aws][:aws_instance_type] defaults to 'm1.small'" do
        Cucumber::Chef::Config[:aws][:aws_instance_type].should == "m1.small"
      end

    end

  end

  describe "class method: aws_image_id" do

    it "should return ami_image_id if Cucumber::Chef::Config[:aws][:aws_image_id] is set" do
      aws_image_id = "ami-12345678"
      Cucumber::Chef::Config[:aws][:aws_image_id] = aws_image_id
      Cucumber::Chef::Config.aws_image_id.should == aws_image_id
    end

    VALID_RELEASES.each do |release|
      VALID_REGIONS.each do |region|
        VALID_ARCHS.each do |arch|
          VALID_DISK_STORES.each do |disk_store|

            it "should return an ami_image_id if release='#{release}', region='#{region}', arch='#{arch}', disk_store='#{disk_store}'" do
              Cucumber::Chef::Config[:aws][:ubuntu_release] = release
              Cucumber::Chef::Config[:aws][:region] = region
              Cucumber::Chef::Config[:aws][:aws_instance_arch] = arch
              Cucumber::Chef::Config[:aws][:aws_instance_disk_store] = disk_store

              expect{ Cucumber::Chef::Config.aws_image_id }.to_not raise_error(Cucumber::Chef::ConfigError)
            end

          end
        end
      end
    end

  end

  describe "when configuration is valid" do

    it "should allow changing providers" do
      Cucumber::Chef::Config[:provider] = :aws
      expect{ Cucumber::Chef::Config.verify_keys }.to_not raise_error(Cucumber::Chef::ConfigError)

      Cucumber::Chef::Config[:provider] = :vagrant
      expect{ Cucumber::Chef::Config.verify_keys }.to_not raise_error(Cucumber::Chef::ConfigError)
    end

    it "should allow changing modes" do
      Cucumber::Chef::Config[:mode] = :test
      expect{ Cucumber::Chef::Config.verify_keys }.to_not raise_error(Cucumber::Chef::ConfigError)

      Cucumber::Chef::Config[:mode] = :user
      expect{ Cucumber::Chef::Config.verify_keys }.to_not raise_error(Cucumber::Chef::ConfigError)
    end

    context "when provider is aws" do
      it "should verify the configuration" do
        user = ENV['OPSCODE_USER'] || ENV['USER']
        Cucumber::Chef::Config[:provider] = :aws
        Cucumber::Chef::Config[:aws][:aws_access_key_id] = ENV['AWS_ACCESS_KEY_ID']
        Cucumber::Chef::Config[:aws][:aws_secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY']
        Cucumber::Chef::Config[:aws][:aws_ssh_key_id] = ENV['AWS_SSH_KEY_ID'] || user
        Cucumber::Chef::Config[:aws][:identity_file] = "#{ENV['HOME']}/.chef/#{user}.pem"
        Cucumber::Chef::Config[:aws][:region] = "us-west-2"
        Cucumber::Chef::Config[:aws][:availability_zone] = "us-west-2a"
        expect{ Cucumber::Chef::Config.verify }.to_not raise_error(Cucumber::Chef::ConfigError)
      end
    end

  end

  describe "when configuration is invalid" do

    it "should complain about missing configuration keys" do
      Cucumber::Chef::Config[:provider] = nil
      expect{ Cucumber::Chef::Config.verify_keys }.to raise_error(Cucumber::Chef::ConfigError)

      Cucumber::Chef::Config[:mode] = nil
      expect{ Cucumber::Chef::Config.verify_keys }.to raise_error(Cucumber::Chef::ConfigError)
    end

    it "should complain about invalid configuration key values" do
      Cucumber::Chef::Config[:provider] = :awss
      expect{ Cucumber::Chef::Config.verify_keys }.to raise_error(Cucumber::Chef::ConfigError)

      Cucumber::Chef::Config[:mode] = :userr
      expect{ Cucumber::Chef::Config.verify_keys }.to raise_error(Cucumber::Chef::ConfigError)
    end

    describe "when provider is aws" do

      it "should complain about missing provider configuration keys" do
        Cucumber::Chef::Config[:provider] = :aws
        expect{ Cucumber::Chef::Config.verify_provider_keys }.to raise_error(Cucumber::Chef::ConfigError)
      end

    end

  end

end
