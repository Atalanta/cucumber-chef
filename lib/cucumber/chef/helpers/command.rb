module Cucumber::Chef::Helpers::Command

  def run_chroot_command(name, command, expected_exit_code=0)
    output = %x(chroot #{lxc_rootfs(name)} /bin/bash -c '#{command}' 2>&1)
    raise "run_chroot_command(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

  def run_remote_command(name, command, expected_exit_code=0)
    output = %x(ssh -o ConnectTimeout=5 #{$servers[name][:ip]} '#{command}' 2>&1)
    raise "run_remote_command(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

  def run_command(command, expected_exit_code=0)
    output = %x(#{command} 2>&1)
    raise "run_command(#{command}) failed (#{$?})" if ($? != expected_exit_code)
    output
  end

end
