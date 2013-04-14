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

    module Utility
      module LogHelper

        def log_key_value(key, value, max_key_length)
          $logger.info { " %s%s: %s" % [ key.upcase, '.' * (max_key_length - key.length), value.to_s ] }
        end

        def log_page_break(max_key_length, char='-')
          $logger.info { (char * (max_key_length * 2)) }
        end

        def log_dependencies
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

          dependencies
        end

        def log_details
          {
            "program" => $0.to_s.inspect,
            "uname" => %x(uname -a).chomp.strip.inspect,
            "chef_repo" => chef_repo.inspect,
            "log_file" => log_file.inspect,
            "config_rb" => config_rb.inspect,
            "labfile" => labfile.inspect
          }
        end

        def logger
          if (!defined?($logger) || $logger.nil?)
            $logger = ZTK::Logger.new(Cucumber::Chef.log_file)

            if Cucumber::Chef.is_rc?
              $logger.level = ZTK::Logger::DEBUG
            end

            dependencies    = log_dependencies
            details         = log_details

            max_key_length  = [dependencies.keys.map(&:length).max, details.keys.map(&:length).max].max + 2

            log_page_break(max_key_length, '=')

            details.sort.each do |key, value|
              log_key_value(key, value, max_key_length)
            end

            log_page_break(max_key_length)

            dependencies.sort.each do |key, value|
              log_key_value(key, value, max_key_length)
            end

            log_page_break(max_key_length)

          end

          $logger
        end

      end
    end

  end
end
