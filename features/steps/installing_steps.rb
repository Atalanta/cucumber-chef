When /^I build the gem$/ do
  project_root = Pathname.new(File.dirname(__FILE__)).parent.parent.expand_path
  rakefile = File.join(project_root, 'Rakefile')
  File.exist?(rakefile).should be_true
  
  # For some unknown reason, the following fails with
  # Don't know how to build task 'default'
  # Even though running the below in irb, and rake -f Rakefile build
  # works fine
  #
  # silent_system('rake -f #{rakefile} build').should be_true
  
  # HACK: using no path for now

  silent_system('rake build').should be_true
  
end

When /^I install the latest gem$/ do
  project_root = Pathname.new(File.dirname(__FILE__)).parent.parent.expand_path
  pkg_dir = project_root.join('pkg')
  glob = File.join(pkg_dir, '*.gem')
  latest = Dir.glob(glob).sort {|a, b| File.ctime(a) <=> File.ctime(b) }.last
  silent_system("gem install #{latest} --no-ri --no-rdoc").should be_true
end

Then /^I should have cucumber\-chef on my path$/ do
  silent_system("which cucumber-chef").should be_true
end

Then /^I can get help about the cucumber\-chef binary on the command line$/ do
  help_text = %x[cucumber-chef help]
  help_text.include?("cucumber-chef help [TASK]").should be_true
end
