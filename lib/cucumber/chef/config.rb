module Cucumber
  module Chef

    class ConfigError < Error; end

    class Config
      extend(Mixlib::Config)

      KEYS = %w( mode provider ).map(&:to_sym) if !defined?(KEYS)
      MODES = %w( user test ).map(&:to_sym) if !defined?(MODES)
      PROVIDERS = %w( aws vagrant ).map(&:to_sym) if !defined?(PROVIDERS)

      PROVIDER_AWS_KEYS = %w( aws_access_key_id aws_secret_access_key region availability_zone aws_ssh_key_id identity_file ).map(&:to_sym) if !defined?(PROVIDER_AWS_KEYS)

################################################################################

      def self.inspect
        configuration.inspect
      end

################################################################################

      def self.load
        config_rb = Cucumber::Chef.locate(:file, ".cucumber-chef", "config.rb")
        self.from_file(config_rb)
        self.verify
        self
      rescue Errno::ENOENT, UtilityError
        raise ConfigError, "Could not find your cucumber-chef configuration file; did you run 'cucumber-chef init'?"
      end

      def self.test
        self.load
        self[:mode] = :test
        self
      end

################################################################################

      def self.verify
        self.verify_keys
        self.verify_provider_keys
        eval("self.verify_provider_#{self[:provider].to_s.downcase}")
      end

################################################################################

      def self.verify_keys
        missing_keys = KEYS.select{ |key| !self[key.to_sym] }
        raise ConfigError, "Configuration incomplete, missing configuration keys: #{missing_keys.join(", ")}" if missing_keys.count > 0

        invalid_keys = KEYS.select{ |key| !eval("#{key.to_s.upcase}S").include?(self[key]) }
        raise ConfigError, "Configuration incomplete, invalid configuration keys: #{invalid_keys.join(", ")}" if invalid_keys.count > 0
      end

################################################################################

      def self.verify_provider_keys
        missing_keys = eval("PROVIDER_#{self[:provider].to_s.upcase}_KEYS").select{ |key| !self[self[:provider]].key?(key) }
        raise ConfigError, "Configuration incomplete, missing provider configuration keys: #{missing_keys.join(", ")}" if missing_keys.count > 0
      end

################################################################################

      def self.verify_provider_aws
        if self[:aws][:aws_access_key_id] && self[:aws][:aws_secret_access_key]
          compute = Fog::Compute.new(:provider => 'AWS',
                                     :aws_access_key_id => self[:aws][:aws_access_key_id],
                                     :aws_secret_access_key => self[:aws][:aws_secret_access_key])
          compute.describe_availability_zones
        end
      rescue Fog::Service::Error => err
        raise ConfigError, "Invalid AWS credentials.  Please check your configuration."
      end

      def self.verify_provider_vagrant
        raise ConfigError, "Not yet implemented."
      end

################################################################################

      def self.aws_image_id
        if self[:aws][:aws_image_id]
          return self[:aws][:aws_image_id]
        elsif (self[:aws][:ubuntu_release] && self[:aws][:region])
          ami = Ubuntu.release(self[:aws][:ubuntu_release]).amis.find do |ami|
            ami.arch == (self[:aws][:aws_instance_arch] || "i386") &&
            ami.root_store == (self[:aws][:aws_instance_disk_store] || "instance-store") &&
            ami.region == self[:aws][:region]
          end
          return ami.name if ami
        end
        raise ConfigError, "Could not find a valid AMI image ID.  Please check your configuration."
      end

################################################################################

      mode      :user
      provider  :aws

      aws       Hash[ :ubuntu_release => "maverick",
                      :aws_instance_arch => "i386",
                      :aws_instance_disk_store => "instance-store",
                      :aws_instance_type => "m1.small",
                      :aws_security_group => "cucumber-chef" ]

      vagrant   Hash.new

    end

  end
end
