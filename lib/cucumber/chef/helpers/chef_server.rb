module Cucumber::Chef::Helpers::ChefServer

  def chef_server_node_destroy(name)
    Chef::Node.load("cucumber-chef-#{name}").destroy rescue nil
  end

  def chef_server_client_destroy(name)
    Chef::ApiClient.load("cucumber-chef-#{name}").destroy rescue nil
  end

end
