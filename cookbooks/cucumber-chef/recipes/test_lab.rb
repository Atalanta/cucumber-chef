%w(rsync build-essential libxml2-dev libxslt1-dev).each do |p|
  package p
end

%w(rspec cucumber cucumber-chef).each do |g|
  gem_package g
end

directory "/root/.ssh" do
  owner "root"
  mode "0600"
end

cookbook_file "/root/.ssh/config" do
  source "ssh-config"
end
