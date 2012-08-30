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

Then /^path "([^\"]*)" should exist$/ do |dir|
  parent = File.dirname dir
  child = File.basename dir
  command = "ls %s" % [
    parent
  ]
  @output = @connection.exec!(command)
  @output.should =~ /#{child}/
end

Then /^path "([^\"]*)" should be owned by "([^\"]*)"$/ do |path, owner|
  command = "stat -c %%U:%%G %s" % [
    path
  ]
  @output = @connection.exec!(command)
  @output.should =~ /#{owner}/
end

Then /^file "([^\"]*)" should( not)? contain "([^\"]*)"$/ do |path, boolean, content|
  command = "cat %s" % [
    path
  ]
  @output = @connection.exec!(command)
  if (!boolean)
    @output.should =~ /#{content}/
  else
    @output.should_not =~ /#{content}/
  end
end

Then /^package "([^\"]*)" should be installed$/ do |package|
  command = ""
  if system "which dpkg > /dev/null"
    command = "dpkg --list"
  elsif system "which yum > /dev/null"
    command = "yum list"
# could easily add more cases here, if I knew what they were :)
  end

  @output = @connection.exec!(command)
  @output.should =~ /#{package}/
end
