require File.join(File.dirname(__FILE__), "../../spec_helper.rb")

describe Cucumber::Chef::Config do
  before(:all) do
    @orgname = ENV["ORGNAME"]
    @opscode_user = ENV["OPSCODE_USER"]
  end

  after(:each) do
    ENV["ORGNAME"] = @orgname
    ENV["OPSCODE_USER"] = @opscode_user
  end

  describe "verification" do
    describe "when ORGNAME is not set" do
      it "should raise" do
        ENV["ORGNAME"] = ""
        expect {
          subject.verify
        }.to raise_error(Cucumber::Chef::ConfigError, /ORGNAME/)
      end
    end

    describe "when OPSCODE_USER is not set" do
      it "should raise" do
        ENV["OPSCODE_USER"] = ""
        expect {
          subject.verify
        }.to raise_error(Cucumber::Chef::ConfigError, /OPSCODE_USER/)
      end
    end

    describe "when configuration is invalid" do
      it "should complain about missing keys" do
        subject.config[:chef_server_url] = nil
        subject.config[:knife][:aws_access_key_id] = nil
        expect {
          subject.verify
        }.to raise_error(Cucumber::Chef::ConfigError, /chef_server_url.*aws_access_key_id/)
      end

      describe "when node name is invalid" do
        it "should raise" do
          ENV["OPSCODE_USER"] = "REALLYBOGUSORGNAME"
          expect {
            subject.verify
          }.to raise_error(Cucumber::Chef::ConfigError, /Opscode platform credentials/)
        end
      end

      describe "when aws_access_key_id is empty" do
        it "should raise" do
          subject.config[:knife][:aws_access_key_id] = "bogus"
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

  describe "when knife.rb is missing" do
    it "should raise" do
      begin
        # Handle case of local .chef directory for gem development
        chef_dir = (File.exist?('.chef') ? Pathname('.chef') : Pathname("~/.chef")).expand_path
        (chef_dir + "knife.rb").rename(chef_dir + "knife.rb.bak")
        config_file = chef_dir + "knife.rb"
        expect { subject.config }.to raise_error(Cucumber::Chef::ConfigError)
      ensure
        (chef_dir + "knife.rb.bak").rename(chef_dir + "knife.rb")
      end
    end
  end

  describe "when configuration is valid" do

    it "should list the configuration values" do
      output = subject.list.join("\n")
      output.should match(/node_name:/)
      output.should match(/knife\[:aws_secret_access_key\]:/)
    end

    it "should return the configuration values" do
      subject[:node_name].should == @opscode_user
    end

    it "should allow setting configuration values" do
      subject[:mode] = "blah"
      subject[:knife][:aws_access_key_id] = "bogus"
      subject[:mode].should == "blah"
      subject[:knife][:aws_access_key_id].should == "bogus"
    end

    it "should provide a method for getting a test mode configuration" do
      config = Cucumber::Chef::Config.test_config
      config[:mode].should == "test"
    end

    it "should know it is in test mode" do
      Cucumber::Chef::Config.test_config.test_mode?.should be
    end

    it "should know it is not in test_mode" do
      Cucumber::Chef::Config.new.test_mode?.should_not be
    end

    describe "and an ami is specified" do
      it "should be returned" do
        subject[:knife][:aws_image_id] = "my-test-ami"
        subject.aws_image_id.should == "my-test-ami"
      end
    end

    describe "and no ami is specified but a release, region, arch and disk store are" do
      VALID_RELEASES = %w(lucid maverick)
      VALID_REGIONS = %w(us-west-1 us-east-1 eu-west-1)
      VALID_ARCHS = %w(i386 amd64)
      VALID_DISK_STORES = %w(instance-store ebs)

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
      VALID_AMIS = %w()

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

      it "should get a valid ami if i386 specified" do
        subject[:knife][:aws_instance_arch] = "i386"
        VALID_AMIS.include?(subject.aws_image_id).should == true
#        subject.aws_image_id.should == "ami-0dc6fe79"
      end

      it "should get a a valid ami if i386 specified" do
        subject[:knife][:region] = "us-west-1"
        subject[:knife][:aws_instance_arch] = "i386"
        VALID_AMIS.include?(subject.aws_image_id).should == true
#        subject.aws_image_id.should == "ami-f3c59db6"
      end

      it "should get a valid ami if amd64 specified" do
        subject[:knife][:aws_instance_arch] = "amd64"
        subject.aws_image_id.should == "ami-fbc6fe8f"
      end

      it "should get an ebs backed instance if specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        subject.aws_image_id.should == "ami-e3c6fe97"
      end

      it "should get a large ebs backed instance if specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        subject[:knife][:aws_instance_arch] = "amd64"
        subject.aws_image_id.should == "ami-edc6fe99"
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

