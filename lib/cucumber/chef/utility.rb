################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber
  module Chef

    class UtilityError < Error; end

    module Utility

################################################################################

      def is_rc?
        ((Cucumber::Chef::VERSION =~ /rc/) || (Cucumber::Chef::VERSION =~ /pre/))
      end

################################################################################

      def locate(type, *args)
        pwd = Dir.pwd.split(File::SEPARATOR)
        (pwd.length - 1).downto(0) do |i|
          candidate = File.join(pwd[0..i], args)
          case type
          when :file
            if (File.exists?(candidate) && !File.directory?(candidate))
              return File.expand_path(candidate)
            end
          when :directory
            if (File.exists?(candidate) && File.directory?(candidate))
              return File.expand_path(candidate)
            end
          when :any
            if File.exists?(candidate)
              return File.expand_path(candidate)
            end
          end
        end

        message = "Could not locate #{type} '#{File.join(args)}'."
        raise UtilityError, message
      end

################################################################################

      def locate_parent(child)
        parent = (locate(:any, child).split(File::SEPARATOR) rescue nil)
        raise UtilityError, "Could not locate parent of '#{child}'." unless parent
        File.expand_path(File.join(parent[0..(parent.length - 2)]))
      end

################################################################################

      def generate_do_not_edit_warning(message=nil)
        warning = Array.new
        warning << "#"
        warning << "# WARNING: Automatically generated file; DO NOT EDIT!"
        warning << [ "# Cucumber-Chef v#{Cucumber::Chef::VERSION}", message ].compact.join(" ")
        warning << "# Generated on #{Time.now.utc.to_s}"
        warning << "#"
        warning.join("\n")
      end

################################################################################

      def external_ip
        %x(wget -q -O - checkip.dyndns.org|sed -e 's/.*Current IP Address: //' -e 's/<.*$//').chomp.strip
      end

################################################################################

      def chef_pre_11
        return false if (Cucumber::Chef::Config.chef[:version].downcase == "latest")
        (Cucumber::Chef::Config.chef[:version].to_f < 11.0)
      end

################################################################################
# Config Helpers
################################################################################

      def provider_config
        Cucumber::Chef::Config[Cucumber::Chef::Config.provider]
      end

################################################################################
# Path Helpers
################################################################################

      def ensure_directory(dir)
        FileUtils.mkdir_p(File.dirname(dir))
      end

      def chef_repo
        (Cucumber::Chef.locate_parent(".chef") rescue nil)
      end

      def in_chef_repo?
        ((chef_repo && File.exists?(chef_repo) && File.directory?(chef_repo)) ? true : false)
      end

################################################################################

      def root_dir
        File.expand_path(File.join(File.dirname(__FILE__), "..", "..", ".."), File.dirname(__FILE__))
      end

################################################################################

      def home_dir
        result = (ENV['CUCUMBER_CHEF_HOME'] || File.join(Cucumber::Chef.locate_parent(".chef"), ".cucumber-chef"))
        ensure_directory(result)
        result
      end

      def provider_dir
        result = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s)
        ensure_directory(result)
        result
      end

################################################################################

      def artifacts_dir
        result = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "artifacts")
        ensure_directory(result)
        result
      end

################################################################################

      def log_file
        result = File.join(Cucumber::Chef.home_dir, "cucumber-chef.log")
        ensure_directory(result)
        result
      end

################################################################################

      def config_rb
        result = File.join(Cucumber::Chef.home_dir, "config.rb")
        ensure_directory(result)
        result
      end

################################################################################

      def labfile
        result = File.join(Cucumber::Chef.chef_repo, "Labfile")
        ensure_directory(result)
        result
      end

################################################################################

      # def knife_rb
      #   knife_rb = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "knife.rb")
      #   FileUtils.mkdir_p(File.dirname(knife_rb))
      #   knife_rb
      # end

################################################################################

      def chef_user
        Cucumber::Chef::Config.user
      end

      def chef_identity
        result = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "#{chef_user}.pem")
        ensure_directory(result)
        result
      end

################################################################################

      def build_home_dir(user)
        ((user == "root") ? "/root" : "/home/#{user}")
      end

################################################################################
# Bootstraping SSH Helpers
################################################################################

      def bootstrap_user
        provider_config[:bootstrap_user]
      end

      def bootstrap_user_home_dir
        build_home_dir(provider_config[:bootstrap_user])
      end

      def bootstrap_identity
        bootstrap_identity = provider_config[:identity_file]
        File.exists?(bootstrap_identity) && File.chmod(0400, bootstrap_identity)
        bootstrap_identity
      end

################################################################################
# Test Lab SSH Helpers
################################################################################

      def lab_user
        provider_config[:lab_user]
      end

      def lab_user_home_dir
        build_home_dir(provider_config[:lab_user])
      end

      def lab_identity
        lab_identity = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "id_rsa-#{lab_user}")
        File.exists?(lab_identity) && File.chmod(0400, lab_identity)
        lab_identity
      end

      def lab_ip
        provider_config[:ssh][:lab_ip]
      end

      def lab_ssh_port
        provider_config[:ssh][:lab_port]
      end

      def lab_hostname_short
        Cucumber::Chef::Config.test_lab[:hostname]
      end

      def lab_hostname_full
        "#{lab_hostname_short}.#{Cucumber::Chef::Config.test_lab[:tld]}"
      end

################################################################################
# Container SSH Helpers
################################################################################

      def lxc_user
        provider_config[:lxc_user]
      end

      def lxc_user_home_dir
        build_home_dir(provider_config[:lxc_user])
      end

      def lxc_identity
        lxc_identity = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "id_rsa-#{lxc_user}")
        File.exists?(lxc_identity) && File.chmod(0400, lxc_identity)
        lxc_identity
      end

################################################################################

      def tag(name=nil)
        [ name, "v#{Cucumber::Chef::VERSION}" ].compact.join(" ")
      end

################################################################################

      def build_command(name, *args)
        executable = (Cucumber::Chef.locate(:file, "bin", name) rescue "/usr/bin/env #{name}")
        [executable, args].flatten.compact.join(" ")
      end

################################################################################
# BOOT
################################################################################

      def boot(name=nil)
        if !in_chef_repo?
          message = "It does not look like you are inside a chef-repo!  Please relocate to one and execute your command again!"
          logger.fatal { message }
          raise message
        end
        name and logger.info { "loading #{name}" }
        logger.info { "boot(#{Cucumber::Chef.config_rb})" }
        Cucumber::Chef::Config.load
        Cucumber::Chef::Labfile.load(Cucumber::Chef.labfile)
      end

################################################################################

      def logger
        if (!defined?($logger) || $logger.nil?)
          $logger = ZTK::Logger.new(Cucumber::Chef.log_file)
          Cucumber::Chef.is_rc? and ($logger.level = ZTK::Logger::DEBUG)

          dependencies = {
            "cucumber_chef_version" => Cucumber::Chef::VERSION.inspect,
            "fog_version" => ::Fog::VERSION.inspect,
            "ruby_version" => RUBY_VERSION.inspect,
            "ruby_patchlevel" => RUBY_PATCHLEVEL.inspect,
            "ruby_platform" => RUBY_PLATFORM.inspect,
            "ztk_version" => ::ZTK::VERSION.inspect
          }
          if RUBY_VERSION >= "1.9"
            dependencies.merge!("ruby_engine" => RUBY_ENGINE.inspect)
          end

          details = {
            "program" => $0.to_s.inspect,
            "uname" => %x(uname -a).chomp.strip.inspect,
            "chef_repo" => chef_repo.inspect,
            "log_file" => log_file.inspect,
            "config_rb" => config_rb.inspect,
            "labfile" => labfile.inspect
          }

          max_key_length = [dependencies.keys.collect{ |key| key.to_s.length }.max, details.keys.collect{ |key| key.to_s.length }.max].max + 2

          $logger.info { ("=" * 80) }
          details.sort.each do |key, value|
            $logger.info { " %s%s: %s" % [ key.upcase, '.' * (max_key_length - key.length), value.to_s ] }
          end
          $logger.info { ("-" * (max_key_length * 2)) }
          dependencies.sort.each do |key, value|
            $logger.info { " %s%s: %s" % [ key.upcase, '.' * (max_key_length - key.length), value.to_s ] }
          end
          $logger.info { ("-" * (max_key_length * 2)) }

        end

        $logger
      end

    end

  end
end

################################################################################
