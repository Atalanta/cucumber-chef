module Cucumber::Chef::Helpers::ChefServer

  def chef_server_node_destroy(name)
    Chef::Node.load(name).destroy rescue nil
  end

  def chef_server_client_destroy(name)
    Chef::ApiClient.load(name).destroy rescue nil
  end

end
