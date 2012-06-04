module Cucumber::Chef::Helpers::Command

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

  def command_run_chroot(name, command, expected_exit_code=0)
    output = %x(chroot #{container_root(name)} /bin/bash -c '#{command}' 2>&1)
    raise "command_run_chroot(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

  def command_run_local(command, expected_exit_code=0)
    output = %x(#{command} 2>&1)
    raise "command_run_local(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

end
