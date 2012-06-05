Given /^I have a server called (.*)$/ do |name|
  @server = (@server || {}).merge(name => Hash.new(nil))
end

And /^(.*) is (.*)$/ do |name, persistant|
  @server[name][:persist] = !(persistant =~ /non-persistant/i)
end

And /^(.*) has an IP address of (.*)$/ do |name, ip|
  @server[name][:ip] = ip
end

And /^(.*) has a MAC address of (.*)$/ do |name, mac|
  @server[name][:mac] = ip
end

And /^(.*) has been provisioned$/ do |name|
  server_create(name, @server[name])
end

And /^the (.*) role has been added to the (.*) run list$/ do |role, name|
  chef_set_client_attributes(@server[name], :run_list => ["role[#{role}]"])
end

And /^the (.*) recipe has been added to the (.*) run list$/ do |recipe, name|
  chef_set_client_attributes(@server[name], :run_list => ["recipe[#{recipe}]"])
end

And /^the chef-client has been run on (.*)$/ do |name|
  chef_run_client(name)
end
