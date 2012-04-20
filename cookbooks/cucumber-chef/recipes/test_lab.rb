%w[rsync build-essential libxml2-dev libxslt1-dev].each do |pkg|
  package pkg
end

node['cucumber-chef'][:gems].each do |gem|
  gem_package gem[:name]
  source gem[:source] if gem[:source]
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