################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
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

    class LoggerError < Error; end

    class Logger < ::Logger

      SEVERITIES = Severity.constants.inject([]) {|arr,c| arr[Severity.const_get(c)] = c; arr}

################################################################################

      def initialize(file=nil)
        if file.nil?
          config_path = File.join(Cucumber::Chef.locate_parent(".chef"), ".cucumber-chef")
          FileUtils.mkdir_p(config_path)
          file = File.join(config_path, "cucumber-chef.log")
        end

        #super(file, 7, (1024 * 1024))
        super(file)
        set_log_level
      end

################################################################################

      def parse_caller(at)
        if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
          file = Regexp.last_match[1]
          line = Regexp.last_match[2]
          method = Regexp.last_match[3]
          "#{File.basename(file)}:#{line}:#{method} | "
        else
          ""
        end
      end

################################################################################

      def add(severity, message = nil, progname = nil, &block)
        return if (@level > severity)

        called_by = parse_caller(caller[1])

        msg = (block && block.call)
        return if (msg.nil? || msg.strip.empty?)
        message = [message, progname, msg].delete_if{|i| i == nil}.join(": ")
        message = "%19s.%06d | %5s | %5s | %s%s\n" % [Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"), Time.now.utc.usec, Process.pid.to_s, SEVERITIES[severity], called_by, message]

        @logdev.write(message)

        true
      end

################################################################################

      def set_log_level(level="INFO")
        log_level = (ENV['LOG_LEVEL'] || level)
        self.level = Cucumber::Chef::Logger.const_get(log_level.to_s.upcase)
      end

################################################################################

    end

  end
end

################################################################################
