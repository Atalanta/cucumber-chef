Given /^I have a server called "([^\"]*)"$/ do |name|
  @name = name
  @server = (@server || {}).merge(@name => Hash.new(nil))
end

And /^it is (.*)$/ do |persistant|
  @server[@name][:persist] = !(persistant =~ /non-persistant/i)
end

And /^it has an IP address of (.*)$/ do |ip|
  @server[@name][:ip] = ip
end

And /^it has a MAC address of (.*)$/ do |mac|
  @server[@name][:mac] = ip
end

And /^the server has been provisioned$/ do
  server_create(@name, @server[@name])
end


And /^the (.*) role has been applied$/ do |role|
  chef_set_client_attributes(@server[:name], :run_list => ["role[#{role}]"])
end

And /^the (.*) recipe has been applied$/ do |recipe|
  chef_set_client_attributes(@server[:name], :run_list => ["recipe[#{recipe}]"])
end


And /^the chef-client has been run$/ do
  chef_run_client(@name)
end
