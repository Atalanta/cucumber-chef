module Cucumber::Chef::Helpers::TestLab

  def test_lab_config_dhcpd
    dhcpd_lxc_config = File.join("/etc/dhcp3/lxc.conf")
    File.open(dhcpd_lxc_config, 'w') do |f|
      $servers.each do |key, value|
        f.puts("")
        f.puts("host #{key} {")
        f.puts("  hardware ethernet #{value[:mac]};")
        f.puts("  fixed-address #{value[:ip]};")
        f.puts("  option host-name \"#{key}\";")
        f.puts("  ddns-hostname \"#{key}\";")
        f.puts("}")
      end
    end
    command_run_local("service dhcp3-server restart")
  end

end
