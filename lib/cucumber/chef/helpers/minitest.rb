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

module Cucumber::Chef::Helpers::MiniTest

  def enable_minitest(name)
    @chef_client_attributes[:run_list].unshift("recipe[minitest-handler]")
    chef_config_client(name)
  end
  
  def run_minitests(name)
    chef_run = command_run_remote(name, "/usr/bin/chef-client -j /etc/chef/attributes.json -N #{name} -l info")
    test_result = chef_run.drop_while {|e| e !~ /^# Running tests/}.take_while {|e| e !~ /^[.*] INFO/}
    puts test_result
    test_result
  end
  
end

