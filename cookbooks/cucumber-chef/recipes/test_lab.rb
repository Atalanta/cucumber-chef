%w[rsync build-essential libxml2-dev libxslt1-dev].each do |pkg|
  package pkg
end

%w[cucumber-chef rspec cucumber cucumber-nagios].each do |gem|
  gem_package gem
end

directory "/root/.ssh" do
  mode "0600"
  owner "root"
end

cookbook_file "/root/.ssh/config" do
  source "permissive-ssh-config"
end

cookbook_file "/root/.ssh/id_rsa" do
  source "cucumber-private-key"
  mode "0600"
  owner "root"
end

