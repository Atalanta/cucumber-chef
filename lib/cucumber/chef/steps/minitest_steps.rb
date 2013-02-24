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

When /^I enable the running of MiniTest suites for "(.*?)"$/ do |name|
  $cc_client.test_lab.drb.enable_minitest(name)
end

Then /^the tests should run and pass on "(.*?)"$/ do |name|
  results = $cc_client.test_lab.drb.run_minitests(name)
  results.last.scan(/assertions.*(\d).*failures.*(\d).*errors.*(\d).*skips/).flatten.map { |v| v.to_i }.should == [0,0,0]
end
