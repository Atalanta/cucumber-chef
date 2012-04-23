%w(build-essential binutils-doc autoconf flex bison libxml2-dev libxslt1-dev).each do |p|
  package p
end

%w(rspec cucumber cucumber-nagios cucumber-chef).each do |g|
  gem_package g
end

directory "/root/.ssh" do
  owner "root"
  mode "0600"
end

cookbook_file "/root/.ssh/git-key.rsa" do
  source "git-private-key"
end

cookbook_file "/root/.ssh/config" do
  source "ssh-config"
end

cookbook_file "/root/.ssh/id_rsa" do
  source "cucumber-private-key"
  mode "0600"
  owner "root"
end

cookbook_file "/root/.bashrc" do
  source "add-git-identity"
end
