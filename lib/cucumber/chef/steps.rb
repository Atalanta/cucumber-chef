require 'cucumber/chef/steps/ssh_steps'

After do
  list_containers.each do |container|
    destroy_container(container)
  end
end
