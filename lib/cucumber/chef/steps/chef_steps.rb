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
    data_bag = entry['databag']
    data_bag_path = entry['databag_path']
    $test_lab.knife_cli(%Q{data bag create "#{data_bag}"}, :silence => true)
    $test_lab.knife_cli(%Q{data bag from file "#{data_bag}" "#{data_bag_path}"}, :silence => true)
  end
end

And /^the following (databag|databags) (has|have) been (deleted|removed):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    data_bag = entry['databag']
    $test_lab.knife_cli(%Q{data bag delete "#{data_bag}" --yes}, :silence => true)
  end
end

################################################################################

And /^the following (role|roles) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    role = entry['role']
    role_path = entry['role_path']

    if File.extname(role).empty?
      Dir.glob(File.join(role_path, "#{role}.*")).each do |role_file|
        $test_lab.knife_cli(%Q{role from file #{role_file}}, :silence => true)
      end
    else
      $test_lab.knife_cli(%Q{role from file #{File.join(role_path, role)}}, :silence => true)
    end
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
    $test_lab.knife_cli(%Q{cookbook upload #{cookbooks.join(" ")} -o #{cookbook_path}}, :silence => true)
  end
end

And /^all of the cookbooks in "([^\"]*)" (has|have) been (updated|uploaded)$/ do |cookbook_path, ignore0, ignore1|
  $test_lab.knife_cli(%Q{cookbook upload -a -o #{cookbook_path}}, :silence => true)
end

################################################################################

And /^the following (environment|environments) (has|have) been (updated|uploaded):$/ do |ignore0, ignore1, ignore2, table|
  table.hashes.each do |entry|
    environment = entry['environment']
    environment_path = entry['environment_path']

    if File.extname(environment).empty?
      Dir.glob(File.join(environment_path, "#{environment}.*")).each do |environment_file|
        $test_lab.knife_cli(%Q{environment from file #{environment_file}}, :silence => true)
      end
    else
      $test_lab.knife_cli(%Q{environment from file #{File.join(environment_path, environment)}}, :silence => true)
    end
  end
end

################################################################################
