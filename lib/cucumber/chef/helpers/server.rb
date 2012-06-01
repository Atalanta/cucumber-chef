module Cucumber::Chef::Helpers::Server

  def log(name, ip, message)
    STDOUT.puts("\033[34m  * #{ip}: (LXC) '#{name}' #{message}\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)
  end

  def server_create(name, attributes={})
    if (attributes[:persist] && $servers[name])
      attributes = $servers[name]
    else
      container_destroy(name) if container_exists?(name)
      attributes = { :ip => generate_ip, :mac => generate_mac, :persist => false }.merge(attributes)
    end
    $servers = ($servers || {}).merge(name => attributes)

    log(name, $servers[name][:ip], "Building") if $servers[name]

    test_lab_config_dhcpd
    container_config_network(name)
    container_create(name)
    sleep(1) until Cucumber::Chef::SSH.ready?($servers[name][:ip])

    log(name, $servers[name][:ip], "Ready") if $servers[name]
  end

  def server_destroy(name)
    log(name, $servers[name][:ip], "Destroy") if $servers[name]

    container_destroy(name)
  end

  def servers
    containers
  end

end
