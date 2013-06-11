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
require 'cucumber/chef/utility/bootstrap_helper'
require 'cucumber/chef/utility/chef_helper'
require 'cucumber/chef/utility/dir_helper'
require 'cucumber/chef/utility/file_helper'
require 'cucumber/chef/utility/lab_helper'
require 'cucumber/chef/utility/log_helper'
require 'cucumber/chef/utility/lxc_helper'

require 'net/http'
require 'whichr'

module Cucumber
  module Chef

    class UtilityError < Error; end

    module Utility

      include Cucumber::Chef::Utility::BootstrapHelper
      include Cucumber::Chef::Utility::ChefHelper
      include Cucumber::Chef::Utility::DirHelper
      include Cucumber::Chef::Utility::FileHelper
      include Cucumber::Chef::Utility::LabHelper
      include Cucumber::Chef::Utility::LogHelper
      include Cucumber::Chef::Utility::LXCHelper

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
        ::Net::HTTP.get('checkip.dyn.com','/').match(/Current IP Address: ([\d\.]+)</)[1]
      end

################################################################################

      def provider_config
        Cucumber::Chef::Config[Cucumber::Chef::Config.provider]
      end

      def ensure_directory(dir)
        FileUtils.mkdir_p(File.dirname(dir))
      end

      def build_home_dir(user)
        ((user == "root") ? "/root" : "/home/#{user}")
      end

      def ensure_identity_permissions(identity)
        (File.exists?(identity) && File.chmod(0400, identity))
      end

      def tag(name=nil)
        [ name, "v#{Cucumber::Chef::VERSION}" ].compact.join(" ")
      end

      def build_command(name, *args)
        if OS.windows?
          executable = ::RubyWhich.new.which(name)[0]
        else
          executable = (Cucumber::Chef.locate(:file, "bin", name) rescue "/usr/bin/env #{name}")
        end
        [executable, args].flatten.compact.join(" ")
      end

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

    end

################################################################################

  end
end

################################################################################
