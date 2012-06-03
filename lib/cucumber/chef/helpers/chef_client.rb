module Cucumber::Chef::Helpers::ChefClient

  # call this in a Before hook
  def chef_set_client_config(config={})
    @chef_client_config = { :log_level => :debug,
                            :log_location => "/var/log/chef.log",
                            :chef_server_url => "https://api.opscode.com/organizations/#{config[:orgname]}",
                            :validation_client_name => "#{config[:orgname]}-validator" }.merge(config)
  end

  # call this before chef_run_client
  def chef_set_client_attributes(name, attributes={})
    @chef_client_attributes = attributes.merge(:tags => ["cucumber-chef-container"])
  end

  def chef_run_client(name)
    chef_config_client(name)
    command_run_remote(name, "/usr/bin/chef-client -j /etc/chef/attributes.json -N #{name}")
  end

  def chef_config_client(name)
    client_rb = File.join("/", container_root(name), "etc/chef/client.rb")
    FileUtils.mkdir_p(File.dirname(client_rb))
    File.open(client_rb, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("Chef Client Configuration"))
      f.puts("")
      f.puts("log_level               :#{@chef_client_config[:log_level]}")
      f.puts("log_location            \"#{@chef_client_config[:log_location]}\"")
      f.puts("chef_server_url         \"#{@chef_client_config[:chef_server_url]}\"")
      f.puts("validation_client_name  \"#{@chef_client_config[:validation_client_name]}\"")
      f.puts("node_name               \"#{name}\"")
    end

    attributes_json = File.join("/", container_root(name), "etc", "chef", "attributes.json")
    FileUtils.mkdir_p(File.dirname(attributes_json))
    File.open(attributes_json, 'w') do |f|
      f.puts(@chef_client_attributes.to_json)
    end

    command_run_local("cp /etc/chef/validation.pem #{container_root(name)}/etc/chef/ 2>&1")
  end

end
