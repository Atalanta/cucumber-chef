module Cucumber::Chef::Helpers::TestLab

  def create_dhcp_config
    dhcpd_lxc_config = File.join("/etc/dhcp3/lxc.conf")
    File.open(dhcpd_lxc_config, 'w') do |f|
      f.puts("option subnet-mask 255.255.0.0;")
      f.puts("option broadcast-address 192.168.255.255;")
      f.puts("option routers 192.168.255.254;")
      f.puts("option domain-name \"cucumber-chef.org\";")
      f.puts("option domain-name-servers 8.8.8.8, 8.8.4.4;")
      f.puts("")
      f.puts("subnet 192.168.0.0 netmask 255.255.0.0 {")
      f.puts("  range 192.168.255.1 192.168.255.100;")
      f.puts("}")
      $servers.each do |key, value|
        f.puts("")
        f.puts("host #{key} {")
        f.puts("  hardware ethernet #{value[:mac]};")
        f.puts("  fixed-address #{value[:ip]};")
        f.puts("}")
      end
    end
    run_command("service dhcp3-server restart")
  end

end
