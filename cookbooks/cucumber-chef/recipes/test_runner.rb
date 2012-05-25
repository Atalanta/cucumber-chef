directory "/root/.ssh" do
  owner "root"
  group "root"
  mode "0700"
end

cookbook_file "/root/.ssh/config" do
  source "ssh-config"
  owner "root"
  group "root"
  mode "0600"
end

cookbook_file "/root/.gemrc" do
  source "gem-rc"
  owner "root"
  group "root"
  mode "0644"
end
