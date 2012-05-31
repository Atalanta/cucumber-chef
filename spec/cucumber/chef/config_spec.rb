require "spec_helper"

VALID_AMIS = %w(ami-f3c59db6 ami-adc59de8 ami-a1c59de4 ami-afc59dea ami-0fac7566 ami-37af765e ami-8fac75e6 ami-0baf7662 ami-0dc6fe79 ami-e3c6fe97 ami-fbc6fe8f ami-edc6fe99 ami-1d154e58 ami-39154e7c ami-2b154e6e ami-3b154e7e ami-7b8f5712 ami-d38f57ba ami-098f5760 ami-d78f57be ami-d57942a1 ami-db7942af ami-df7942ab ami-c57942b1)

VALID_RELEASES = %w(lucid maverick)
VALID_REGIONS = %w(us-west-1 us-east-1 eu-west-1)
VALID_ARCHS = %w(i386 amd64)
VALID_DISK_STORES = %w(instance-store ebs)

describe Cucumber::Chef::Config do

  before(:all) do
    Cucumber::Chef::Config.mode = :test
    @original_config = Cucumber::Chef::Config.hash_dup
  end

  after(:each) do
    Cucumber::Chef::Config.configuration = @original_config
  end

  describe "default values" do

    before(:each) do
      load File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "lib", "cucumber", "chef", "config.rb"))
    end

    after(:each) do
      load File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper.rb"))
    end

    it "Cucumber::Chef::Config[:mode] defaults to :user" do
      Cucumber::Chef::Config[:mode].should == :user
    end

    it "Cucumber::Chef::Config[:provider] defaults to :aws" do
      Cucumber::Chef::Config[:provider].should == :aws
    end

    describe "Cucumber::Chef::Config[:aws] default values" do

      it "Cucumber::Chef::Config[:aws][:security_group] defaults to 'cucumber-chef'" do
        Cucumber::Chef::Config[:aws][:security_group].should == 'cucumber-chef'
      end

    end

  end

end

=begin
  describe "verification" do

    describe "when configuration is invalid" do
      it "should complain about missing keys" do
        subject.aws[:aws_access_key_id] = nil
        expect {
          subject.verify
        }.to raise_error(Cucumber::Chef::ConfigError, /aws_access_key_id/)
      end

      describe "when aws_access_key_id is empty" do
        it "should raise" do
          subject.aws[:aws_access_key_id] = "bogus"
          expect {
            subject.verify
          }.to raise_error(Cucumber::Chef::ConfigError, /AWS credentials/)
        end
      end
    end

    describe "when configuration is valid" do
      it "should not raise" do
        subject.verify
      end
    end
  end

  describe "when configuration is valid" do

    it "should list the configuration values" do
      output = subject.inspect
      output.should match(/:aws_secret_access_key/)
    end

    it "should allow setting configuration values" do
      subject.mode = :blah
      subject.mode.should == :blah

      subject.aws[:aws_access_key_id] = "bogus"
      subject.aws[:aws_access_key_id].should == "bogus"
    end

    it "should provide a method for getting a test mode configuration" do
      config = Cucumber::Chef::Config.test
      config.mode.should == :test
    end

    it "should know it is in test mode" do
      Cucumber::Chef::Config.test.test?.should be
    end

    it "should know it is not in test_mode" do
      Cucumber::Chef::Config.load.test?.should_not be
    end

    describe "and an ami is specified" do
      it "should be returned" do
        subject[:knife][:aws_image_id] = "my-test-ami"
        subject.aws_image_id.should == "my-test-ami"
      end
    end

    describe "and no ami is specified but a release, region, arch and disk store are" do

      before(:each) do
        subject[:knife][:aws_image_id] = nil
        subject[:knife][:ubuntu_release] = nil
        subject[:knife][:region] = nil
        subject[:knife][:aws_instance_arch] = nil
        subject[:knife][:aws_instance_disk_store] = nil
      end

      VALID_RELEASES.each do |release|
        VALID_REGIONS.each do |region|
          VALID_ARCHS.each do |arch|
            VALID_DISK_STORES.each do |disk_store|

              it "should get a valid ami if release #{release}, region #{region}, arch #{arch}, disk store #{disk_store}" do
                subject[:knife][:ubuntu_release] = release
                subject[:knife][:region] = region
                subject[:knife][:aws_instance_arch] = arch
                subject[:knife][:aws_instance_disk_store] = disk_store

                VALID_AMIS.include?(subject.aws_image_id).should == true
              end

            end
          end
        end
      end

    end

    describe "and no ami is specified but region and ubuntu release are" do

      before(:each) do
        subject[:knife][:aws_image_id] = nil
        subject[:knife][:ubuntu_release] = "lucid"
        subject[:knife][:region] = "eu-west-1"
        subject[:knife][:aws_instance_arch] = nil
        subject[:knife][:aws_instance_disk_store] = nil
      end

      it "should default to a valid ami if unspecified" do
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end

      it "should get a valid ami if arch i386 specified" do
        subject[:knife][:aws_instance_arch] = "i386"
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end

      it "should get a valid ami if region us-west-1 and arch i386 specified" do
        subject[:knife][:region] = "us-west-1"
        subject[:knife][:aws_instance_arch] = "i386"
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end

      it "should get a valid ami if arch amd64 specified" do
        subject[:knife][:aws_instance_arch] = "amd64"
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end

      it "should get a valid ami if disk store ebs specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end

      it "should get a valid ami if instance large and disk store ebs specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        subject[:knife][:aws_instance_type] = "m1.large"
        VALID_AMIS.include?(subject.aws_image_id).should == true
      end
    end

    it "should default to an m1.small instance type" do
      subject.aws_instance_type.should == "m1.small"
    end

    describe "and an instance type is specified" do
      it "should return the specified instance type" do
        subject[:knife][:aws_instance_type] = "m1.large"
        subject.aws_instance_type.should == "m1.large"
      end
    end
  end

  it "should default to security group cucumber-chef" do
    subject.security_group.should == "cucumber-chef"
  end

  describe "and a security group is specified" do
    it "should return the specified security group" do
      subject[:knife][:aws_security_group] = "my-security-group"
      subject.security_group.should == "my-security-group"
    end
  end
end
=end
