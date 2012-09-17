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

require 'readline'
require 'socket'
require 'stringio'

################################################################################

require 'chef'
require 'chef/cookbook_uploader'
require 'erubis'
require 'fog'
require 'json'
require 'mixlib/config'
require 'net/ssh'
require 'net/ssh/proxy/command'
require 'net/sftp'
require 'ubuntu_ami'
require 'ztk'

################################################################################

require 'cucumber/chef/version'

module Cucumber
  module Chef

    class Error < StandardError; end

    autoload :Bootstrap, 'cucumber/chef/bootstrap'
    autoload :Bootstrap, 'cucumber/chef/bootstrap'
    autoload :Command, 'cucumber/chef/command'
    autoload :Config, 'cucumber/chef/config'
    autoload :Logger, 'cucumber/chef/logger'
    autoload :Provisioner, 'cucumber/chef/provisioner'
    autoload :TCPSocket, 'cucumber/chef/tcp_socket'
    autoload :Template, 'cucumber/chef/template'
    autoload :TestLab, 'cucumber/chef/test_lab'

    require 'cucumber/chef/utility'
    extend(Cucumber::Chef::Utility)

  end
end

################################################################################
