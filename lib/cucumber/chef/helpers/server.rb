module Cucumber::Chef::Helpers::Server

  def log(name, ip, message)
    STDOUT.puts("\033[34m  * #{ip}: (LXC) '#{name}' #{message}\033[0m")
    STDOUT.flush if STDOUT.respond_to?(:flush)
  end

  def create_server(name, attributes={})
    if (attributes[:persist] && $servers[name])
      attributes = $servers[name]
    else
      destroy_container(name) if container_exists?(name)
      attributes = { :ip => generate_ip, :mac => generate_mac, :persist => false }.merge(attributes)
    end
    $servers = ($servers || {}).merge(name => attributes)

    log(name, $servers[name][:ip], "Building")

    create_dhcp_config
    create_network_config(name)
    create_container(name)
    create_client_rb(name)
    sleep(1) until Cucumber::Chef::SSH.ready?($servers[name][:ip])

    log(name, $servers[name][:ip], "Ready")
  end

  def destroy_server(name)
    log(name, $servers[name][:ip], "Destroy")
    destroy_container(name)
  end

  def list_servers
    list_containers
  end

end
