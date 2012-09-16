# Given /^I have no public keys set$/ do
#   @auth_methods = %w(password)
# end

# Then /^I can ssh to "([^\"]*)" with the following credentials:$/ do |hostname, table|
#   @auth_methods ||= %w(publickey password)

#   credentials = table.hashes
#   credentials.each do |creds|
#     lambda {
#       $drb_test_lab.ssh = Cucumber::Chef::SSH.new
#       creds["hostname"] and ($drb_test_lab.ssh.config[:host] = creds["hostname"])
#       creds["username"] and ($drb_test_lab.ssh.config[:ssh_user] = creds["username"])
#       creds["password"] and ($drb_test_lab.ssh.config[:ssh_password] = creds["password"])
#       creds["keyfile"] and ($drb_test_lab.ssh.config[:identity_file] = creds["keyfile"])
#       # $drb_test_lab.ssh.config[:identity_file] = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{$drb_test_lab.ssh.config[:ssh_user]}")
#       # $drb_test_lab.ssh.exec("nohup sudo cc-server #{Cucumber::Chef.external_ip}")

#       #Net::SSH.start(session["hostname"], creds["username"], :password => creds["password"], :auth_methods => @auth_methods)
#     }.should_not raise_error(Net::SSH::AuthenticationFailed)
#   end
# end

# Then /^I can ssh to the following hosts with these credentials:$/ do |table|
#   @keys ||= []
#   @auth_methods ||= %w(password)
#   session_details = table.hashes

#   session_details.each do |session|
#     # # initialize a list of keys and auth methods for just this session, as
#     # # session can have session-specific keys mixed with global keys
#     # session_keys = Array.new(@keys)
#     # session_auth_methods = Array.new(@auth_methods)

#     # # you can pass in a keyfile in the session details, so we need to
#     # if session["keyfile"]
#     #   session_keys << session["keyfile"]
#     #   session_auth_methods << "publickey"
#     # end

#     lambda {
#       $drb_test_lab.ssh = Cucumber::Chef::SSH.new
#       session["hostname"] and ($drb_test_lab.ssh.config[:host] = session["hostname"])
#       session["username"] and ($drb_test_lab.ssh.config[:ssh_user] = session["username"])
#       session["password"] and ($drb_test_lab.ssh.config[:ssh_password] = session["password"])
#       session["keyfile"] and ($drb_test_lab.ssh.config[:identity_file] = session["keyfile"])
#       $drb_test_lab.ssh.exec("hostname")
#     }.should_not raise_error
#   end
# end

# Given /^I have the following public keys:$/ do |table|
#   @keys = []
#   public_key_paths = table.hashes

#   public_key_paths.each do |key|
#     File.exist?(key["keyfile"]).should be_true
#     FileUtils.chmod(0600, key["keyfile"])
#     @keys << key["keyfile"]
#   end

#   @auth_methods ||= %w(password)
#   @auth_methods << "publickey"
# end

When /^I ssh to "([^\"]*)" with the following credentials:$/ do |hostname, table|
  session = table.hashes.first
  lambda {

    @connection = Cucumber::Chef::SSH.new

    @connection.config[:proxy] = true
    @connection.config[:proxy_host] = $test_lab.labs_running.first.public_ip_address
    @connection.config[:proxy_ssh_user] = "ubuntu"
    @connection.config[:proxy_identity_file] = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{@connection.config[:proxy_ssh_user]}")

    hostname and (@connection.config[:host] = hostname)
    session["username"] and (@connection.config[:ssh_user] = session["username"])
    session["password"] and (@connection.config[:ssh_password] = session["password"])
    session["keyfile"] and (@connection.config[:identity_file] = session["keyfile"])

  }.should_not raise_error
end

And /^I run "([^\"]*)"$/ do |command|
  @output = @connection.exec(command, :silence => true)
end

Then /^I should( not)? see "([^\"]*)" in the output$/ do |boolean, string|
  if (!boolean)
    @output.should =~ /#{string}/
  else
    @output.should_not =~ /#{string}/
  end
end

Then /^I should( not)? see the "([^\"]*)" of "([^\"]*)" in the output$/ do |boolean, key, name|
  if (!boolean)
    @output.should =~ /#{$servers[name][key.downcase.to_sym]}/i
  else
    @output.should_not =~ /#{$servers[name][key.downcase.to_sym]}/i
  end
end

Then /^(path|directory|file|symlink) "([^\"]*)" should exist$/ do |type, path|
  parent = File.dirname path
  child = File.basename path
  command = "ls %s" % [
    parent
  ]
  @output = @connection.exec(command)
  @output.should =~ /#{child}/

# if a specific type (directory|file) was specified, test for it
  command = "stat -c %%F %s" % [
    path
  ]
  @output = @connection.exec(command)
  types = {
    "file" => /regular file/,
    "directory" => /directory/,
    "symlink" => /symbolic link/
  }

  if types.keys.include? type
    @output.should =~ types[type]
  end
#  if type == "file"
#    @output.should =~ /regular file/
#  end
#  if type == "directory"
#    @output.should =~ /directory/
#  end
#  if type == "symlink"
#    @output.should =~ /symbolic link/
#  end
end

Then /^(?:path|directory|file) "([^\"]*)" should be owned by "([^\"]*)"$/ do |path, owner|
  command = "stat -c %%U:%%G %s" % [
    path
  ]
  @output = @connection.exec(command)
  @output.should =~ /#{owner}/
end

# we can now match multi-line strings. We want to match *contiguous lines*
Then /^file "([^\"]*)" should( not)? contain/ do |path, boolean, content|
  command = "cat %s" % [
    path
  ]

# turn the command-line output and the expectation string into Arrays and strip
# leading and trailing cruft from members
  @output = @connection.exec(command).split("\n").map{ |i| i.strip }
  content = content.split("\n").map{ |i| i.strip }

# assume no match
  match = false
  count = 0

# step through the command output array
  while count < @output.length
    current = @output[count]

# if we get a match with the start of the expectation
    if @output[count] == content[0]

# take a slice of the same size as that expectation
      slice = @output[count..count + content.length - 1]

# and see if they match
      if content == slice
        match = true
      end
    end
    count += 1
  end

# there's a neater way to express this logic, but it's 17:30 and I'm going home
  if (!boolean)
    match.should == true
  else
    match.should == false
  end
end

Then /^package "([^\"]*)" should be installed$/ do |package|
  command = ""
  if (dpkg = @connection.exec("which dpkg 2> /dev/null")).length > 0
    command = "#{dpkg.chomp} --get-selections"
  elsif (yum = @connection.exec("which yum 2> /dev/null")).length > 0
    command = "#{yum.chomp} -q list installed"
# could easily add more cases here, if I knew what they were :)
  end

  @output = @connection.exec(command)
  @output.should =~ /#{package}/
end

# This regex is a little ugly, but it's so we can accept any of these
#
# * "foo" is running
# * service "foo" is running
# * application "foo" is running
# * process "foo" is running
#
# basically because I couldn't decide what they should be called. Maybe there's
# an Official Cucumber-chef Opinion on this. Still, Rubular is fun :)

# TiL that in Ruby regexes, "?:" marks a non-capturing group, which is how this
# works
Then /^(?:(?:service|application|process)? )?"([^\"]*)" should( not)? be running$/ do |service, boolean|
  command = "ps ax"
  @output = @connection.exec(command)
  if (!boolean)
    @output.should =~ /#{service}/
  else
    @output.should_not =~ /#{service}/
  end
end
