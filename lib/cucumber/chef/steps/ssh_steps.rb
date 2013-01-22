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

      @ssh_sessions[id].config.proxy_host_name = $test_lab.public_ip
      @ssh_sessions[id].config.proxy_user = Cucumber::Chef.lab_user
      @ssh_sessions[id].config.proxy_keys = Cucumber::Chef.lab_identity

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

    @connection and !@connection.ssh.closed? and @connection.ssh.close
    @connection = ZTK::SSH.new

    @connection.config.proxy_host_name = $test_lab.public_ip
    @connection.config.proxy_port = $test_lab.ssh_port
    @connection.config.proxy_user = Cucumber::Chef.lab_user
    @connection.config.proxy_keys = Cucumber::Chef.lab_identity

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
  @output = @connection.exec(command, :silence => true).output
  Cucumber::Chef.logger.info { @output.chomp }
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
    @output.should =~ /#{$test_lab.drb.servers[name][key.downcase.to_sym]}/i
  else
    @output.should_not =~ /#{$test_lab.drb.servers[name][key.downcase.to_sym]}/i
  end
end

Then /^(path|directory|file|symlink) "([^\"]*)" should exist$/ do |type, path|
  parent = File.dirname path
  child = File.basename path
  command = "ls %s" % [
    parent
  ]
  @output = @connection.exec(command).output
  @output.should =~ /#{child}/

# if a specific type (directory|file) was specified, test for it
  command = "stat -c %%F %s" % [
    path
  ]
  @output = @connection.exec(command).output
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
  @output = @connection.exec(command).output
  @output.should =~ /#{owner}/
end

# we can now match multi-line strings. We want to match *contiguous lines*
Then /^file "([^\"]*)" should( not)? contain/ do |path, boolean, content|
  command = "cat %s" % [
    path
  ]

# turn the command-line output and the expectation string into Arrays and strip
# leading and trailing cruft from members
  @output = @connection.exec(command).output.split("\n").map{ |i| i.strip }
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
  if (dpkg = @connection.exec("which dpkg 2> /dev/null").output).length > 0
    command = "#{dpkg.chomp} --get-selections"
  elsif (yum = @connection.exec("which yum 2> /dev/null").output).length > 0
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
  @output = @connection.exec(command).output
  if (!boolean)
    @output.should =~ /#{service}/
  else
    @output.should_not =~ /#{service}/
  end
end
