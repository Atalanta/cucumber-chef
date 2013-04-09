################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

And /^the following (databag|databags) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    create_data_bag(entry['databag'], entry['databag_path'])
  end
end

And /^the following (databag|databags) (has|have) been (deleted|removed):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    delete_data_bag(entry['databag'])
  end
end

################################################################################

And /^the following (role|roles) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    role_from_file(entry['role'], entry['role_path'])
  end
end

################################################################################

And /^the following (cookbook|cookbooks) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  cookbooks = table.hashes.inject(Hash.new) do |memo, entry|
    cookbook = entry['cookbook']
    cookbook_path = entry['cookbook_path']

    memo.merge(cookbook_path => [cookbook]) { |k,o,n| k = o << n }
  end

  cookbooks.each do |cookbook_path, cookbooks|
    $cc_client.test_lab.knife_cli(%(cookbook upload #{cookbooks.join(" ")} -o #{cookbook_path}), :silence => true)
  end
end

And /^all of the cookbooks in "([^\"]*)" (has|have) been (updated|uploaded)$/ do |cookbook_path, ignore0, ignore1|
  $cc_client.test_lab.knife_cli(%(cookbook upload -a -o #{cookbook_path}), :silence => true)
end

################################################################################

And /^the following (environment|environments) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    environment = entry['environment']
    environment_path = entry['environment_path']

    if File.extname(environment).empty?
      Dir.glob(File.join(environment_path, "#{environment}.*")).each do |environment_file|
        $cc_client.test_lab.knife_cli(%(environment from file #{environment_file}), :silence => true)
      end
    else
      $cc_client.test_lab.knife_cli(%(environment from file #{File.join(environment_path, environment)}), :silence => true)
    end
  end
end

################################################################################
