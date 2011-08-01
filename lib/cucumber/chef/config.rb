require "ubuntu_ami"

module Cucumber
  module Chef
    class ConfigError < Error ; end

    class Config
      KEYS = %w[mode node_name chef_server_url client_key validation_key validation_client_name]
      KNIFE_KEYS = %w[aws_access_key_id aws_secret_access_key region aws_image_id availability_zone aws_ssh_key_id identity_file]

      def initialize
        config[:mode] = "user"
      end

      def self.mode
        config.test_mode? ? 'test' : 'user'
      end

      def [](key)
        config[key]
      end

      def []=(key, value)
        config[key] = value
      end

      def config
        unless @config
          full_path = Dir.pwd.split(File::SEPARATOR)
          (full_path.length - 1).downto(0) do |i|
            knife_file = File.join(full_path[0..i] + [".chef", "knife.rb"])
            if File.exist?(knife_file)
              ::Chef::Config.from_file(knife_file)
              @config = ::Chef::Config
              return @config
            end
          end
          raise ConfigError.new("Couldn't find knife.rb")
        end
        @config
      end

      def self.test_config
        config = self.new
        config[:mode] = "test"
        config
      end

      def test_mode?
        config[:mode] == "test"
      end

      def list
        values = []
        KEYS.each do |key|
          value = config[key]
          values << "#{key}: #{value}"
        end
        KNIFE_KEYS.each do |key|
          value = config[:knife][key.to_sym]
          values << "knife[:#{key}]: #{value}"
        end
        values
      end

      def verify
        @errors = []
        verify_orgname
        verify_opscode_user
        verify_keys
        verify_opscode_platform_credentials
        verify_aws_credentials
        if @errors.size > 0
          raise ConfigError.new(@errors.join("\n"))
        end
      end

      def aws_image_id
        if self[:knife][:aws_image_id]
          self[:knife][:aws_image_id]
        elsif self[:knife][:ubuntu_release] && self[:knife][:region]
          query = ::UbuntuAmi.new(self[:knife][:ubuntu_release])
          instance_arch = query.arch_size(self[:knife][:aws_instance_arch] || "i386")
          disk_store = query.disk_store(self[:knife][:aws_instance_disk_store] || "instance-store")
          query.run["#{query.region_fix(self[:knife][:region])}_#{instance_arch}#{disk_store}"]
        end
      end

    private

      def verify_orgname
        if !ENV["ORGNAME"] || ENV["ORGNAME"] == ""
          @errors << "Your organisation must be set using the environment variable ORGNAME."
        end
      end

      def verify_opscode_user
        if !ENV["OPSCODE_USER"] || ENV["OPSCODE_USER"] == ""
          @errors << "Your Opscode platform username must be set using the environment variable OPSCODE_USER."
        end
      end

      def verify_keys
        missing_keys = []
        KEYS.each do |key|
          value = config[key]
          missing_keys << key unless value && value != ""
        end
        KNIFE_KEYS.each do |key|
          missing_keys << "knife[:#{key}]" unless value = config[:knife][key.to_sym]
        end
        if missing_keys.size > 0
          @errors << "Incomplete config file, please specify: #{missing_keys.join(", ")}."
        end
      end

      def verify_opscode_platform_credentials
        username = config['node_name']
        if username
          req = Net::HTTP.new('community.opscode.com', 80)
          code = req.request_head("/users/#{username}").code
        end
        if username == "" || code != "200"
          @errors << "Invalid Opscode platform credentials. Please check."
        end
      end

      def verify_aws_credentials
        if config[:knife][:aws_access_key_id] && config[:knife][:aws_secret_access_key]
          compute = Fog::Compute.new(:provider => 'AWS',
                                     :aws_access_key_id => config[:knife][:aws_access_key_id],
                                     :aws_secret_access_key => config[:knife][:aws_secret_access_key])
          compute.describe_availability_zones
        else
          @errors << "Invalid AWS credentials. Please check."
        end
      rescue Fog::Service::Error => err
        @errors << "Invalid AWS credentials. Please check."
      end
    end
  end
end
