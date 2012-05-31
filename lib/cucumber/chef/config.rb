require "mixlib/config"
require "ubuntu_ami"

module Cucumber
  module Chef

    class ConfigError < Error; end

    class Config
      extend(Mixlib::Config)

      PROVIDER_AWS_KEYS = %w( aws_access_key_id aws_secret_access_key region availability_zone aws_ssh_key_id identity_file )

################################################################################

      def self.inspect
        configuration.inspect
      end

################################################################################

      def self.load
        config_file = File.join(Dir.pwd, ".cucumber-chef", "config.rb")
        config_file = Pathname.new(config_file).expand_path
        self.from_file(config_file)
        self.verify
        self
      end

      def self.test
        self.load
        self.mode = :test
        selfd
      end

################################################################################

      def self.user?
        self.mode == :user
      end

      def self.test?
        self.mode == :test
      end

      def self.provider_config
        case self.provider
        when :aws
          self.aws
        when :vagrant
          self.vagrant
        end
      end

################################################################################

      def self.verify
        self.verify_keys
        self.verify_provider
      end

################################################################################

      def self.verify_keys
        missing_keys = eval("PROVIDER_#{self.provider.to_s.upcase}_KEYS.select {|key| !self.provider_config.key?(key.to_sym) }")
        raise ConfigError("Configuration incomplete, missing provider keys: #{missing_keys.join(", ")}") if missing_keys.count > 0
      end

################################################################################

      def self.verify_provider
        case self.provider
        when :aws
          self.verify_provider_aws
        when :vagrant
          self.verify_provider_vagrant
        end
      end

      def self.verify_provider_aws
        if self.provider_config[:aws_access_key_id] && self.provider_config[:aws_secret_access_key]
          compute = Fog::Compute.new(:provider => 'AWS',
                                     :aws_access_key_id => self.provider_config[:aws_access_key_id],
                                     :aws_secret_access_key => self.provider_config[:aws_secret_access_key])
          compute.describe_availability_zones
        end
      rescue Fog::Service::Error => err
        raise ConfigError("Invalid AWS credentials.  Please check your configuration.")
      end

      def self.verify_provider_vagrant
        raise ConfigError("Not yet implemented.")
      end

################################################################################

      def self.aws_image_id_proc
        if self.aws[:aws_image_id]
          return self.aws[:aws_image_id]
        elsif (self.aws[:ubuntu_release] && self.aws[:region])
          ami = Ubuntu.release(self.aws[:ubuntu_release]).amis.find do |ami|
            ami.arch == (self.aws[:aws_instance_arch] || "i386") &&
            ami.root_store == (self.aws[:aws_instance_disk_store] || "instance-store") &&
            ami.region == self.aws[:region]
          end
          return (ami.name rescue "")
        end
        nil
      end

################################################################################

      mode      :user
      provider  :aws

      aws       Hash[ :security_group => "cucumber-chef",
                      :ubuntu_release => "maverick",
                      :aws_instance_arch => "i386",
                      :aws_instance_disk_store => "instance-store",
                      :aws_instance_type => "m1.small" ]

      vagrant   Hash.new

    end

  end
end
