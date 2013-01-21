################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber::Chef::Helpers::ChefServer

################################################################################

  def chef_server_node_destroy(name)
    (::Chef::Node.load(name).destroy rescue nil)
    log("destroyed chef node $#{name}$")
  end

################################################################################

  def chef_server_client_destroy(name)
    (::Chef::ApiClient.load(name).destroy rescue nil)
    log("destroyed chef client $#{name}$")
  end

################################################################################

  def load_cookbook(cookbook, cookbook_path)
    if !File.exists?(cookbook_path)
      raise "Cookbook path does not exist!"
    end
    cookbook_repo = ::Chef::CookbookLoader.new(cookbook_path)
    cookbook_repo.each do |name, cbook|
      next if name != cookbook
      ::Chef::CookbookUploader.new(cbook, cookbook_path, :force => true).upload_cookbooks
      log("uploaded chef cookbook $#{cookbook}$ from $#{cookbook_path}$")
    end
  end

################################################################################

  def load_role(role, role_path)
    expanded_role_path = File.expand_path(role_path)
    if !File.exists?(expanded_role_path)
      raise "Role path, '#{expanded_role_path}', does not exist!"
    end
    ::Chef::Config[:role_path] = expanded_role_path
    role = ::Chef::Role.from_disk(role)
    role.save
    log("updated chef role $#{role}$ from $#{role_path}$")
  end

################################################################################

  def get_databag(databag)
    @rest ||= ::Chef::REST.new(Chef::Config[:chef_server_url])
    @rest.get_rest("data/#{databag}")
  rescue Net::HTTPServerException => e
    raise unless e.to_s =~ /^404/
  end

  def destroy_databag(databag)
    @rest ||= ::Chef::REST.new(Chef::Config[:chef_server_url])
    @rest.delete_rest("data/#{databag}")
  rescue Net::HTTPServerException => e
    raise unless e.to_s =~ /^404/
  end

################################################################################

  def create_databag(databag)
    @rest ||= ::Chef::REST.new(Chef::Config[:chef_server_url])
    @rest.post_rest("data", { "name" => databag })
  rescue Net::HTTPServerException => e
    raise unless e.to_s =~ /^409/
  end

  def load_databag_item(databag_item_path)
    ::Yajl::Parser.parse(IO.read(databag_item_path))
  end

  def load_databag(databag, databag_path)
    create_databag(databag)
    items = Dir.glob(File.expand_path(File.join(databag_path, "*.{json,rb}")))
    if (items.size == 0)
      raise "Could not find any of the data bags you defined!"
    end
    items.each do |item|
      next if File.directory?(item)

      item_name = %w( json rb ).collect{ |ext| (item =~ /#{ext}/ ? File.basename(item, ".#{ext}") : nil) }.compact.first
      item_path = File.basename(item)
      databag_item_path = File.expand_path(File.join(databag_path, item_path))

      data_bag_item = ::Chef::DataBagItem.new
      data_bag_item.data_bag(databag)
      raw_data = load_databag_item(databag_item_path)
      data_bag_item.raw_data = raw_data.dup
      data_bag_item.save

      loop do
        chef_data = ::Chef::DataBagItem.load(databag, item_name).raw_data
        break if chef_data == raw_data
        log("waiting on chef data bag to update")
        sleep(1)
      end
      log("updated chef data bag item $#{databag}/#{item_path}$ from $#{databag_path}$")
    end
  end

################################################################################

end

################################################################################
