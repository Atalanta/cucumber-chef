################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2012 Cucumber-Chef
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

require 'readline'
require 'socket'
require 'stringio'

################################################################################

require 'chef'
require 'erubis'
require 'fog'
require 'json'
require 'mixlib/config'
require 'net/ssh'
require 'net/ssh/proxy/command'
require 'net/sftp'
require 'ubuntu_ami'

################################################################################

module Cucumber
  module Chef

    class Error < StandardError; end

    require 'cucumber/chef/utility'
    extend(Cucumber::Chef::Utility)

  end
end

################################################################################

require 'cucumber/chef/bootstrap'
require 'cucumber/chef/command'
require 'cucumber/chef/config'
require 'cucumber/chef/logger'
require 'cucumber/chef/provisioner'
require 'cucumber/chef/ssh'
require 'cucumber/chef/tcp_socket'
require 'cucumber/chef/template'
require 'cucumber/chef/test_lab'
require 'cucumber/chef/test_runner'
require 'cucumber/chef/version'

################################################################################
