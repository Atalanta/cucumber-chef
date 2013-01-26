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

tag = Cucumber::Chef.tag("cucumber-chef")
puts("  * #{tag}")
Cucumber::Chef.boot(tag)

if (($test_lab = Cucumber::Chef::TestLab.new) && $test_lab.alive?)
  $cc_client = $test_lab.cc_client
  $cc_client.up
else
  message = "No running cucumber-chef test labs to connect to!"
  Cucumber::Chef.logger.fatal { message }
  raise message
end


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

Kernel.at_exit do
  $cc_client.at_exit
end

################################################################################
