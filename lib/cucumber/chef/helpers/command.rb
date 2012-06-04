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

module Cucumber::Chef::Helpers::Command

################################################################################

  def command_run_remote(name, command, expected_exit_code=0)
    output = %x(ssh #{name} '#{command}' 2>&1)
    raise "command_run_remote(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  rescue RuntimeError => e
    if $? == 65280
      puts "Exit Code #{$?}: Retrying..."
      retry
    end
  end

################################################################################

  def command_run_chroot(name, command, expected_exit_code=0)
    output = %x(chroot #{container_root(name)} /bin/bash -c '#{command}' 2>&1)
    raise "command_run_chroot(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

################################################################################

  def command_run_local(command, expected_exit_code=0)
    output = %x(#{command} 2>&1)
    raise "command_run_local(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

################################################################################

end

################################################################################
