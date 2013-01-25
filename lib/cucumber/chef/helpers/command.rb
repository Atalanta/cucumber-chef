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

module Cucumber::Chef::Helpers::Command

################################################################################

  def command_run_remote(name, command, options={})
    expected_exit_code = (options[:expected_exit_code] || 0)
    options.reject!{ |k,v| k == :expected_exit_code }

    identity_file = File.join(Cucumber::Chef.lab_user_home_dir, ".ssh", "id_rsa")

    command = %W(/usr/bin/ssh #{ENV['LOG_LEVEL'] == 'DEBUG' ? "-v" : nil} -i #{identity_file} #{name} #{command})
    ::ZTK::Command.new({:timeout => Cucumber::Chef::Config.command_timeout}.merge(options)).exec(command.compact.join(" "), :silence => true, :exit_code => expected_exit_code)
  end

################################################################################

  def command_run_chroot(name, command, options={})
    expected_exit_code = (options[:expected_exit_code] || 0)
    options.reject!{ |k,v| k == :expected_exit_code }

    command = %Q(/usr/sbin/chroot #{container_root(name)} /bin/bash -c '#{command.gsub("'", '"')}')
    ::ZTK::Command.new({:timeout => Cucumber::Chef::Config.command_timeout}.merge(options)).exec(command, :silence => true, :exit_code => expected_exit_code)
  end

################################################################################

  def command_run_local(command, options={})
    $logger.info { "ONE command_run_local(#{options.inspect})" }

    expected_exit_code = (options[:expected_exit_code] || 0)
    options.reject!{ |k,v| k == :expected_exit_code }

    $logger.info { "TWO command_run_local(#{options.inspect})" }

    command = %Q(/bin/bash -c '#{command.gsub("'", '"')}')
    ::ZTK::Command.new({:timeout => Cucumber::Chef::Config.command_timeout}.merge(options)).exec(command, :silence => true, :exit_code => expected_exit_code)
  end

################################################################################

end

################################################################################
