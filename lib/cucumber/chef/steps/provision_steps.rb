Given /^I have a server called "([^\"]*)"$/ do |name|
  @servers = (@servers || Hash.new(nil)).merge(name => Hash.new(nil))
end

And /^"([^\"]*)" is running "([^\"]*)" "([^\"]*)"$/ do |name, distro, release|
  @servers[name].merge!( :distro => distro, :release => release )
end

And /^"([^\"]*)" has "([^\"]*)" architecture$/ do |name, arch|
  @servers[name].merge!( :arch => arch )
end

And /^"([^\"]*)" should be "([^\"]*)"$/ do |name, persistant|
  @servers[name].merge!( :persist => !(persistant =~ /non-persistant/i) )
end

And /^"([^\"]*)" has an IP address of "([^\"]*)"$/ do |name, ip|
  @servers[name].merge!( :ip => ip )
end

And /^"([^\"]*)" has a MAC address of "([^\"]*)"$/ do |name, mac|
  @servers[name].merge!( :mac => ip )
end

And /^"([^\"]*)" has been provisioned$/ do |name|
  server_create(name, @servers[name])
end

And /^the "([^\"]*)" role has been added to the "([^\"]*)" run list$/ do |role, name|
  chef_set_client_attributes(@servers[name], :run_list => ["role[#{role}]"])
end

And /^the "([^\"]*)" recipe has been added to the "([^\"]*)" run list$/ do |recipe, name|
  chef_set_client_attributes(@servers[name], :run_list => ["recipe[#{recipe}]"])
end

And /^the chef-client has been run on "([^\"]*)"$/ do |name|
  chef_run_client(name)
end
