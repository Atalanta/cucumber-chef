module Cucumber::Chef::Helpers::TestLab

  def test_lab_config_dhcpd
    dhcpd_config = File.join("/etc/dhcp3/test-lab.conf")
    File.open(dhcpd_config, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("DHCPD Configuration"))
      $servers.each do |key, value|
        f.puts
        f.puts("host #{key} {")
        f.puts("  hardware ethernet #{value[:mac]};")
        f.puts("  fixed-address #{value[:ip]};")
        f.puts("  ddns-hostname \"#{key}\";")
        f.puts("}")
      end
    end
    command_run_local("/etc/init.d/dhcp3-server restart")
  end

end
