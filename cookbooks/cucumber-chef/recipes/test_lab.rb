%w(build-essential wget ruby-full ruby-dev libxml2-dev libxslt1-dev).each do |p|
  package p
end

bash "install rubygems" do
  code <<-EOH
cd /tmp
wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.19.tgz
tar zxf rubygems-1.8.19.tgz
cd rubygems-1.8.19
ruby setup.rb --no-format-executable
  EOH
end

%w(rspec cucumber-chef).each do |g|
  gem_package g do
    gem_binary("/usr/bin/gem")
  end
end

%w(root ubuntu).each do |user|
  home_dir = (user == "root" ? "/#{user}" : "/home/#{user}")
  directory "#{home_dir}/.ssh" do
    owner user
    group user
    mode "0700"
  end

  cookbook_file "#{home_dir}/.ssh/config" do
    source "ssh-config"
    owner user
    group user
    mode "0600"
  end

  cookbook_file "#{home_dir}/.gemrc" do
    source "gem-rc"
    owner user
    group user
    mode "0644"
  end

  execute "ssh-keygen -q -N '' -f #{home_dir}/.ssh/id_rsa"
end
