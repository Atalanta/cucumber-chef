module Cucumber::Chef::Helpers::Chef

  # call this in a Before hook
  def set_chef_client(attributes={})
    @chef_client = { :log_level => :debug,
                     :log_location => "/var/log/chef.log",
                     :chef_server_url => "https://api.opscode.com/organizations/#{attributes[:orgname]}",
                     :validation_client_name => "#{attributes[:orgname]}-validator" }.merge(attributes)
  end

  # call this before run_chef
  def set_chef_client_attributes(name, attributes={})
    attributes.merge!(:tags => ["cucumber-chef-container"])
    attributes_json = File.join("/", lxc_rootfs(name), "etc", "chef", "attributes.json")
    FileUtils.mkdir_p(File.dirname(attributes_json))
    File.open(attributes_json, 'w') do |f|
      f.puts(attributes.to_json)
    end
  end

  def run_chef(name)
    run_remote_command(name, "/usr/bin/chef-client -j /etc/chef/attributes.json -N cucumber-chef-#{name}")
  end

  def create_client_rb(name)
    client_rb = File.join("/", lxc_rootfs(name), "etc/chef/client.rb")
    FileUtils.mkdir_p(File.dirname(client_rb))
    File.open(client_rb, 'w') do |f|
      f.puts("log_level               :#{@chef_client[:log_level]}")
      f.puts("log_location            \"#{@chef_client[:log_location]}\"")
      f.puts("chef_server_url         \"#{@chef_client[:chef_server_url]}\"")
      f.puts("validation_client_name  \"#{@chef_client[:validation_client_name]}\"")
      f.puts("node_name               \"cucumber-chef-#{name}\"")
    end
    run_command("cp /etc/chef/validation.pem #{lxc_rootfs(name)}/etc/chef/ 2>&1")
  end

end
