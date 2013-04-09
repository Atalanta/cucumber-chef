################################################################################
#
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

$cc_client = Cucumber::Chef::Client.new
$cc_client.up

################################################################################
# HOOKS
################################################################################

Before do |scenario|
  $cc_client.before(scenario)
end

After do |scenario|
  @connection and @connection.ssh.shutdown!
  $cc_client.after(scenario)
end

################################################################################

Kernel.at_exit do
  $cc_client.at_exit
end

################################################################################
