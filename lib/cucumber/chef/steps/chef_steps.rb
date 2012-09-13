################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Atalanta Systems Ltd
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

And /^the following databags have been updated:$/ do |table|
  table.hashes.each do |entry|
    load_databag(entry['databag'], entry['databag_path'])
  end
end

And /^the following roles have been updated:$/ do |table|
  table.hashes.each do |entry|
    load_role(entry['role'], entry['role_path'])
  end
end

And /^the following cookbooks have been uploaded:$/ do |table|
  table.hashes.each do |entry|
    load_cookbook(entry['cookbook'], entry['cookbook_path'])
  end
end

And /^the following environments have been updated:$/ do |table|
  table.hashes.each do |entry|
    load_environment(entry['environment'], entry['environment_path'])
  end
end
