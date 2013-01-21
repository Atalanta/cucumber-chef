################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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

module Cucumber::Chef::Helpers::Command

################################################################################

  def command_run_remote(name, command, expected_exit_code=0)
    command = %Q(ssh #{name} #{command} 2>&1)
    logger.info { "command_run_remote(#{command})" }
    output = %x(#{command})
    if !expected_exit_code.nil? && ($? != expected_exit_code)
      message = "command_run_remote(#{command}) failed (code=#{$?},output='#{output.chomp}')"
      logger.fatal { message }
      logger.fatal { "output(#{output.chomp})" }
      raise message
    end
    output
  end

################################################################################

  def command_run_chroot(name, command, expected_exit_code=0)
    command = %Q(chroot #{container_root(name)} /bin/bash -c '#{command}' 2>&1)
    logger.info { "command_run_chroot(#{command})" }
    output = %x(#{command})
    if !expected_exit_code.nil? && ($? != expected_exit_code)
      message = "command_run_chroot(#{command}) failed (#{$?})"
      logger.fatal { message }
      logger.fatal { "output(#{output.chomp})" }
      raise message
    end
    output
  end

################################################################################

  def command_run_local(command, expected_exit_code=0)
    command = %Q(/bin/bash -c '#{command}' 2>&1)
    logger.info { "command_run_local(#{command})" }
    output = %x(#{command})
    if !expected_exit_code.nil? && ($? != expected_exit_code)
      message = "command_run_local(#{command}) failed (#{$?})"
      logger.fatal { message }
      logger.fatal { "output(#{output.chomp})" }
      raise message
    end
    output
  end

################################################################################

end

################################################################################
