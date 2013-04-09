################################################################################

# | id | hostname | username | keyfile |
# | root | chef-client | root | keyfile |

When /^I have the following SSH sessions:$/ do |table|
  lambda {
    @ssh_sessions ||= Hash.new
    table.hashes.each do |hash|
      id = hash["id"]
      @ssh_sessions[id] and !@ssh_sessions[id].closed? and @ssh_sessions[id].close
      @ssh_sessions[id] = ZTK::SSH.new

      @ssh_sessions[id].config.proxy_host_name = $cc_client.test_lab.ip
      @ssh_sessions[id].config.proxy_user      = Cucumber::Chef.lab_user
      @ssh_sessions[id].config.proxy_keys      = Cucumber::Chef.lab_identity

      hash['hostname'] and (@ssh_sessions[id].config.host_name = hash['hostname'])
      hash['username'] and (@ssh_sessions[id].config.user = hash['username'])
      hash['password'] and (@ssh_sessions[id].config.password = hash['password'])
      hash['keyfile'] and (@ssh_sessions[id].config.keys = hash['keyfile'])
    end
  }.should_not raise_error
end

################################################################################

When /^I ssh to "([^\"]*)" with the following credentials:$/ do |hostname, table|
  session = table.hashes.first
  lambda {

    @connection and @connection.ssh.shutdown!
    @connection = ZTK::SSH.new(:timeout => 120, :ignore_exit_status => true)

    @connection.config.proxy_host_name = $cc_client.test_lab.ip
    @connection.config.proxy_port      = $cc_client.test_lab.port
    @connection.config.proxy_user      = Cucumber::Chef.lab_user
    @connection.config.proxy_keys      = Cucumber::Chef.lab_identity

    hostname and (@connection.config.host_name = hostname)
    session["password"] and (@connection.config.password = session["password"])

    if username = session["username"]
      if username == "$lxc$"
        @connection.config.user = Cucumber::Chef.lxc_user
      else
        @connection.config.user = username
      end
    end

    if keyfile = session["keyfile"]
      if keyfile == "$lxc$"
        @connection.config.keys = Cucumber::Chef.lxc_identity
      else
        @connection.config.keys = keyfile
      end
    end

  }.should_not raise_error
end

And /^I run "([^\"]*)"$/ do |command|
  @result    = @connection.exec(command, :silence => true)
  @output    = @result.output
  @exit_code = @result.exit_code
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
    @output.should =~ /#{Cucumber::Chef::Containers.all.select{|c| c.name == name}.first.send(key.downcase.to_sym)}/i
  else
    @output.should_not =~ /#{Cucumber::Chef::Containers.all.select{|c| c.name == name}.first.send(key.downcase.to_sym)}/i
  end
end

Then /^the exit code should be "([^\"]*)"$/ do |exit_code|
  @exit_code.to_i.should == exit_code.to_i
end

Then /^(path|directory|file|symlink) "([^\"]*)" should( not)? exist$/ do |type, path, boolean|
  parent  = File.dirname path
  child   = File.basename path
  command = "ls -a %s" % [
      parent
  ]
  @output = @connection.exec(command, :silence => true).output
  if (!boolean)
    @output.should =~ /#{child}/
  else
    @output.should_not =~ /#{child}/
  end

# if a specific type (directory|file) was specified, test for it
  command = "stat -c %%F %s" % [
      path
  ]
  @output = @connection.exec(command, :silence => true).output
  types   = {
      "file"      => /regular file/,
      "directory" => /directory/,
      "symlink"   => /symbolic link/
  }

  if types.keys.include? type
    if (!boolean)
      @output.should =~ types[type]
    end
  end
end

Then /^(?:path|directory|file) "([^\"]*)" should be owned by "([^\"]*)"$/ do |path, owner|
  command = "stat -c %%U:%%G %s" % [
      path
  ]
  @output = @connection.exec(command, :silence => true).output
  @output.should =~ /#{owner}/
end

# we can now match multi-line strings. We want to match *contiguous lines*
Then /^file "([^\"]*)" should( not)? contain/ do |path, boolean, content|
  command = "cat %s" % [
      path
  ]

# turn the command-line output and the expectation string into Arrays and strip
# leading and trailing cruft from members
  @output = @connection.exec(command, :silence => true).output.split("\n").map { |i| i.strip }
  content = content.split("\n").map { |i| i.strip }

# assume no match
  match   = false
  count   = 0

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
  if (dpkg = @connection.exec("which dpkg 2> /dev/null", silence: true).output).length > 0
    command = "#{dpkg.chomp} --get-selections"
  elsif (yum = @connection.exec("which yum 2> /dev/null", silence: true).output).length > 0
    command = "#{yum.chomp} -q list installed"
# could easily add more cases here, if I knew what they were :)
  end

  @result = @connection.exec(command, :silence => true)
  @result.output.should =~ /#{package}/
end

Then /^"mod_([^ ]*)" should be enabled$/ do |mod|
  command = "apache2ctl -t -D DUMP_MODULES"
  @result = @connection.exec(command, :silence => true)
  @result.output.should =~ /#{mod}_module/
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
  @output = @connection.exec(command, :silence => true).output
  if (!boolean)
    @output.should =~ /#{service}/
  else
    @output.should_not =~ /#{service}/
  end
end
