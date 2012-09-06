Given /^I have no public keys set$/ do
  @auth_methods = %w(password)
end

Then /^I can ssh to "([^\"]*)" with the following credentials:$/ do |hostname, table|
  @auth_methods ||= %w(publickey password)

  credentials = table.hashes
  credentials.each do |creds|
    lambda {
      Net::SSH.start(session["hostname"], creds["username"], :password => creds["password"], :auth_methods => @auth_methods)
    }.should_not raise_error(Net::SSH::AuthenticationFailed)
  end
end

Then /^I can ssh to the following hosts with these credentials:$/ do |table|
  @keys ||= []
  @auth_methods ||= %w(password)
  session_details = table.hashes

  session_details.each do |session|
    # initialize a list of keys and auth methods for just this session, as
    # session can have session-specific keys mixed with global keys
    session_keys = Array.new(@keys)
    session_auth_methods = Array.new(@auth_methods)

    # you can pass in a keyfile in the session details, so we need to
    if session["keyfile"]
      session_keys << session["keyfile"]
      session_auth_methods << "publickey"
    end

    lambda {
      @connection = Net::SSH.start(session["hostname"],
                                   session["username"],
                                   :password => session["password"],
                                   :auth_methods => session_auth_methods,
                                   :keys => session_keys)
    }.should_not raise_error
  end
end

Given /^I have the following public keys:$/ do |table|
  @keys = []
  public_key_paths = table.hashes

  public_key_paths.each do |key|
    File.exist?(key["keyfile"]).should be_true
    FileUtils.chmod(0600, key["keyfile"])
    @keys << key["keyfile"]
  end

  @auth_methods ||= %w(password)
  @auth_methods << "publickey"
end

When /^I ssh to "([^\"]*)" with the following credentials:$/ do |hostname, table|
  @keys = []
  @auth_methods ||= %w(password)
  session = table.hashes.first
  session_keys = Array.new(@keys)
  session_auth_methods = Array.new(@auth_methods)
  if session["keyfile"]
    session_keys << session["keyfile"]
    session_auth_methods << "publickey"
  end

  lambda {
    @connection = Net::SSH.start(hostname,
                                 session["username"],
                                 :password => session["password"],
                                 :auth_methods => session_auth_methods,
                                 :keys => session_keys)
  }.should_not raise_error
end

And /^I run "([^\"]*)"$/ do |command|
  @output = @connection.exec!(command)
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

Then /^(path|directory|file) "([^\"]*)" should exist$/ do |type, path|
  parent = File.dirname path
  child = File.basename path
  command = "ls %s" % [
    parent
  ]
  @output = @connection.exec!(command)
  @output.should =~ /#{child}/

# if a specific type (directory|file) was specified, test for it
  command = "stat -c %%F %s" % [
    path
  ]
  @output = @connection.exec!(command)
  if type == "file"
    @output.should =~ /regular file/
  end
  if type == "directory"
    @output.should =~ /directory/
  end
end

Then /^(?:path|directory|file) "([^\"]*)" should be owned by "([^\"]*)"$/ do |path, owner|
  command = "stat -c %%U:%%G %s" % [
    path
  ]
  @output = @connection.exec!(command)
  @output.should =~ /#{owner}/
end

# we can now match multi-line strings. We want to match *contiguous lines*
Then /^file "([^\"]*)" should( not)? contain/ do |path, boolean, content|
  command = "cat %s" % [
    path
  ]

# turn the command-line output and the expectation string into Arrays and strip
# leading and trailing cruft from members
  @output = @connection.exec!(command).split("\n").map{ |i| i.strip }
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
  if (dpkg = @connection.exec!("which dpkg 2> /dev/null")).length > 0
    command = "#{dpkg.chomp} --get-selections"
  elsif (yum = @connection.exec!("which yum 2> /dev/null")).length > 0
    command = "#{yum.chomp} -q list installed"
# could easily add more cases here, if I knew what they were :)
  end

  @output = @connection.exec!(command)
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
  @output = @connection.exec!(command)
  if (!boolean)
    @output.should =~ /#{service}/
  else
    @output.should_not =~ /#{service}/
  end
end
