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

module Cucumber::Chef::Helpers::ChefClient

################################################################################

  # call this in a Before hook
  def chef_set_client_config(config={})
    @chef_client_config = (@chef_client_config || {
      :log_level => :info,
      :log_location => "/var/log/chef/client.log",
      :chef_server_url => "https://api.opscode.com/organizations/#{config[:orgname]}",
      :validation_client_name => "#{config[:orgname]}-validator"
    }).merge(config)
  end

################################################################################

  # call this before chef_run_client
  def chef_set_client_attributes(name, attributes={})
    @chef_client_attributes = (@chef_client_attributes || {}).merge(attributes) { |k,o,n| (k = (o + n)) }
  end

################################################################################

  def chef_run_client(name,*args)
    chef_config_client(name)
    command_run_remote(name, "/bin/rm -f /var/log/chef/client.log ; true")
    output = command_run_remote(name, ["/usr/bin/chef-client -j /etc/chef/attributes.json -N #{name}", args].flatten.join(" "))
    log("chef-client", "ran on node '#{name}'")
    output
  end

################################################################################

  def chef_config_client(name)
    # make sure our configuration location is there
    client_rb = File.join("/", container_root(name), "etc/chef/client.rb")
    FileUtils.mkdir_p(File.dirname(client_rb))

    File.open(client_rb, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("Chef Client Configuration"))
      f.puts
      f.puts("log_level               :#{@chef_client_config[:log_level]}")
      f.puts("log_location            \"#{@chef_client_config[:log_location]}\"")
      f.puts("chef_server_url         \"#{@chef_client_config[:chef_server_url]}\"")
      f.puts("ssl_verify_mode         :verify_none")
      f.puts("validation_client_name  \"#{@chef_client_config[:validation_client_name]}\"")
      f.puts("node_name               \"#{name}\"")
      f.puts("environment             \"#{@chef_client_config[:environment]}\"") if @chef_client_config[:environment]
      f.puts
      f.puts("Mixlib::Log::Formatter.show_time = true")
    end

    attributes_json = File.join("/", container_root(name), "etc", "chef", "attributes.json")
    FileUtils.mkdir_p(File.dirname(attributes_json))
    File.open(attributes_json, 'w') do |f|
      f.puts((@chef_client_attributes || {}).to_json)
    end

    # make sure our log location is there
    log_location = File.join("/", container_root(name), @chef_client_config[:log_location])
    FileUtils.mkdir_p(File.dirname(log_location))

    command_run_local("cp /etc/chef/validation.pem #{container_root(name)}/etc/chef/ 2>&1")
  end

################################################################################

  def chef_client_artifacts(name)
    ssh_user = "root"
    proxy_ssh_user = "ubuntu"

    ssh_private_key_file = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{proxy_ssh_user}")
    File.chmod(0400, ssh_private_key_file)

    ssh = ZTK::SSH.new

    ssh.config.proxy_host_name = $test_lab.labs_running.first.public_ip_address
    ssh.config.proxy_user = proxy_ssh_user
    ssh.config.proxy_keys = ssh_private_key_file

    ssh.config.host_name = name
    ssh.config.user = ssh_user
    ssh.config.keys = ssh_private_key_file

    scenario_tag = $scenario.name.gsub(" ", "_")

    feature_file = $scenario.file_colon_line.split(":").first
    feature_line = $scenario.file_colon_line.split(":").last
    feature_tag = File.basename(feature_file.split("/")[1..-1].join("-"), ".feature")

    puts "feature_tag == #{feature_tag.inspect}"

    artifact_name = ([ feature_tag, name, scenario_tag ].join("-") + ".log").downcase
    puts "artifact_name == #{artifact_name}"

    local_path = File.expand_path(File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "artifacts", artifact_name))
    FileUtils.mkdir_p(File.dirname(local_path))
    remote_path = File.join("/", "var", "log", "chef", "client.log")

    ssh.download(remote_path, local_path)
    File.chmod(0644, local_path)

    ssh.exec("rm -f #{remote_path}")
  end

################################################################################

end

################################################################################
