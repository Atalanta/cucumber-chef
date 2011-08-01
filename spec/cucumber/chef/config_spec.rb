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

    describe "and no ami is specified but region and ubuntu release are" do
      before(:each) do
        UbuntuAmi.any_instance.should_receive(:run).and_return({ "eu_west_large_ebs"=>"large-ebs-instance",
                                                                 "eu_west_small_ebs"=>"small-ebs-instance",
                                                                 "eu_west_large"=>"large-instance",
                                                                 "eu_west_small"=>"small-instance",
                                                                 "us_west_small"=>"us-west-small-instance" })
        subject[:knife][:aws_image_id] = nil
        subject[:knife][:ubuntu_release] = "lucid"
        subject[:knife][:region] = "eu-west-1"
        subject[:knife][:aws_instance_arch] = nil
        subject[:knife][:aws_instance_disk_store] = nil
      end

      it "should default to a small instance if unspecified" do
        subject.aws_image_id.should == "small-instance"
      end

      it "should get a small instance if i386 specified" do
        subject[:knife][:aws_instance_arch] = "i386"
        subject.aws_image_id.should == "small-instance"
      end

      it "should get a us-west small instance if specified" do
        subject[:knife][:region] = "us-west-1"
        subject[:knife][:aws_instance_arch] = "small"
        subject.aws_image_id.should == "us-west-small-instance"
      end

      it "should get a large instance if amd64 specified" do
        subject[:knife][:aws_instance_arch] = "amd64"
        subject.aws_image_id.should == "large-instance"
      end

      it "should get an ebs backed instance if specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        subject.aws_image_id.should == "small-ebs-instance"
      end

      it "should get a large ebs backed instance if specified" do
        subject[:knife][:aws_instance_disk_store] = "ebs"
        subject[:knife][:aws_instance_arch] = "amd64"
        subject.aws_image_id.should == "large-ebs-instance"
      end
    end
  end
end

