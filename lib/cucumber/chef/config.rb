require "ubuntu_ami"

module Cucumber
  module Chef

    class ConfigError < Error; end

    class Config
      KEYS = %w[mode node_name chef_server_url client_key validation_key validation_client_name]
      KNIFE_KEYS = %w[aws_access_key_id aws_secret_access_key region availability_zone aws_ssh_key_id identity_file]
      OPTIONAL_KNIFE_KEYS = %w[aws_instance_arch aws_instance_disk_store aws_instance_type]

      attr_accessor :stdout, :stderr, :stdin

################################################################################

      def self.mode
        config.test_mode? ? :test : :user
      end

      def self.test_config(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        config = self.new(stdout, stderr, stdin)
        config[:mode] = :test
        config
      end

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        @stdout, @stderr, @stdin = stdout, stderr, stdin
        @stdout.sync = true

        config[:mode] = :user
      end

      def test_mode?
        config[:mode] == :test
      end

      def mode
        config[:mode]
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

      def list
        values = []
        KEYS.each do |key|
          value = config[key]
          values << "#{key}: #{value.is_a?(File) ? value.path : value}"
        end
        (KNIFE_KEYS + OPTIONAL_KNIFE_KEYS).each do |key|
          values << "knife[:#{key}]: #{knife_config[key.to_sym]}" if knife_config[key.to_sym]
        end
        if knife_config[:aws_image_id]
          values << "knife[:aws_image_id]: #{knife_config[:aws_image_id]}"
        else
          values << "knife[:ubuntu_release]: #{knife_config[:ubuntu_release]} (aws image id: #{aws_image_id})"
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
        if knife_config[:aws_image_id]
          knife_config[:aws_image_id]
        elsif knife_config[:ubuntu_release] && knife_config[:region]


          ami = Ubuntu.release(knife_config[:ubuntu_release]).amis.find do |ami|
            ami.arch == (knife_config[:aws_instance_arch] || "i386") &&
            ami.root_store == (knife_config[:aws_instance_disk_store] || "instance-store") &&
            ami.region == knife_config[:region]
          end

          @stdout.puts("Using EC2 AMI: #{ami.region} #{ami.name} (#{ami.arch}, #{ami.root_store})") if ami

          (ami.name rescue "")
        end
      end

      def aws_instance_type
        knife_config[:aws_instance_type] || "m1.small"
      end

      def security_group
        knife_config[:aws_security_group] || "cucumber-chef"
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
          missing_keys << "knife[:#{key}]" unless value = knife_config[key.to_sym]
        end
        unless knife_config[:aws_image_id] || knife_config[:ubuntu_release]
          missing_keys << "knife[:aws_image_id] or knife[:ubuntu_release]"
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
        if knife_config[:aws_access_key_id] && knife_config[:aws_secret_access_key]
          compute = Fog::Compute.new(:provider => 'AWS',
                                     :aws_access_key_id => knife_config[:aws_access_key_id],
                                     :aws_secret_access_key => knife_config[:aws_secret_access_key])
          compute.describe_availability_zones
        else
          @errors << "Invalid AWS credentials. Please check."
        end
      rescue Fog::Service::Error => err
        @errors << "Invalid AWS credentials. Please check."
      end

      def knife_config
        self[:knife]
      end

    end

  end
end
