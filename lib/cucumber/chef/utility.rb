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

      def spinner(stdout=STDOUT, stderr=STDERR, stdin=STDIN)
        spinning_chars = %w[| / - \\]
        count = 0
        spinner = Thread.new do
          while count do
            stdout.print spinning_chars[(count+=1) % spinning_chars.length]
            stdout.flush if stdout.respond_to?(:flush)
            sleep(0.25)
            stdout.print "\b"
            stdout.flush if stdout.respond_to?(:flush)
          end
        end
        yield.tap do
          count = false
          spinner.join
        end
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
# Path Helpers
################################################################################

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
        home_dir = File.join(Cucumber::Chef.locate_parent(".chef"), ".cucumber-chef")
        FileUtils.mkdir_p(File.dirname(home_dir))
        home_dir
      end

################################################################################

      def log_file
        log_file = File.join(Cucumber::Chef.home_dir, "cucumber-chef.log")
        FileUtils.mkdir_p(File.dirname(log_file))
        log_file
      end

################################################################################

      def config_rb
        config_rb = File.join(Cucumber::Chef.home_dir, "config.rb")
        FileUtils.mkdir_p(File.dirname(config_rb))
        config_rb
      end

################################################################################

      def knife_rb
        knife_rb = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "knife.rb")
        FileUtils.mkdir_p(File.dirname(knife_rb))
        knife_rb
      end

################################################################################

      def servers_bin
        servers_bin = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "servers.bin")
        FileUtils.mkdir_p(File.dirname(servers_bin))
        servers_bin
      end

################################################################################
# Bootstraping SSH Helpers
################################################################################

      def bootstrap_user
        Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:lab_user]
      end

      def bootstrap_identity
        bootstrap_identity = Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:identity_file]
        File.exists?(bootstrap_identity) && File.chmod(0400, bootstrap_identity)
        bootstrap_identity
      end

################################################################################
# Test Lab SSH Helpers
################################################################################

      def lab_user
        Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:lab_user]
      end

      def lab_user_home_dir
        user = Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:lab_user]
        ((user == "root") ? "/root" : "/home/#{user}")
      end

      def lab_identity
        lab_identity = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "id_rsa-#{lab_user}")
        File.exists?(lab_identity) && File.chmod(0400, lab_identity)
        lab_identity
      end

      def lab_hostname_short
        Cucumber::Chef::Config.test_lab[:hostname]
      end

      def lab_hostname_full
        "#{lab_hostname_s}.#{Cucumber::Chef::Config.test_lab[:tld]}"
      end

################################################################################
# Container SSH Helpers
################################################################################

      def lxc_user
        Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:lxc_user]
      end

      def lxc_user_home_dir
        user = Cucumber::Chef::Config[Cucumber::Chef::Config.provider][:lxc_user]
        ((user == "root") ? "/root" : "/home/#{user}")
      end

      def lxc_identity
        lxc_identity = File.join(Cucumber::Chef.home_dir, Cucumber::Chef::Config.provider.to_s, "id_rsa-#{lab_user}")
        File.exists?(lxc_identity) && File.chmod(0400, lxc_identity)
        lxc_identity
      end

################################################################################

      def tag(name=nil)
        [ name, "v#{Cucumber::Chef::VERSION}" ].compact.join(" ")
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
        load_chef_config
      end

################################################################################
# Load Chef::Config
################################################################################

      def load_chef_config
        test_lab = (Cucumber::Chef::TestLab.new rescue nil)
        if (test_lab && ((test_lab.labs_running.count rescue 0) > 0))
          if File.exists?(Cucumber::Chef.knife_rb)
            logger.info { "load_chef_config(#{Cucumber::Chef.knife_rb})" }
            ::Chef::Config.from_file(Cucumber::Chef.knife_rb)

            chef_server_url = "http://#{test_lab.ip}:4000"
            logger.info { "chef_server_url(#{chef_server_url})" }
            ::Chef::Config[:chef_server_url] = chef_server_url
          else
            logger.warn { "We found the test lab; but the knife config '#{Cucumber::Chef.knife_rb}' was missing!" }
          end
        else
          logger.info { "load_chef_config(#{Cucumber::Chef.knife_rb})" }
          ::Chef::Config.from_file(Cucumber::Chef.knife_rb)
        end
      end

################################################################################

      def logger
        if (!defined?($logger) || $logger.nil?)
          $logger = ZTK::Logger.new(Cucumber::Chef.log_file)
          Cucumber::Chef.is_rc? and ($logger.level = ZTK::Logger::DEBUG)

          headers = {
            "program" => $0.to_s.inspect,
            "cucumber_chef_version" => Cucumber::Chef::VERSION.inspect,
            "uname" => %x(uname -a).chomp.strip.inspect,
            "chef_repo" => chef_repo.inspect,
            "chef_version" => ::Chef::VERSION.inspect,
            "vagrant_version" => ::Vagrant::VERSION.inspect,
            "fog_version" => ::Fog::VERSION.inspect,
            "log_file" => log_file.inspect,
            # "config_rb" => config_rb,
            # "knife_rb" => knife_rb,
            "servers_bin" => servers_bin.inspect,
            "ruby_version" => RUBY_VERSION.inspect,
            "ruby_patchlevel" => RUBY_PATCHLEVEL.inspect,
            "ruby_platform" => RUBY_PLATFORM.inspect
          }
          if RUBY_VERSION >= "1.9"
            headers.merge!("ruby_engine" => RUBY_ENGINE.inspect)
          end
          max_key_length = headers.keys.collect{ |key| key.to_s.length }.max

          $logger.info { ("=" * 80) }
          headers.sort.each do |key, value|
            $logger.info { "%#{max_key_length}s: %s" % [ key.upcase, value.to_s ] }
          end
        end

        $logger
      end

    end

  end
end

################################################################################
