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

module Cucumber::Chef::Helpers::Utility

################################################################################

  def logger
    Cucumber::Chef.logger
  end

################################################################################

  def generate_ip
    octets = [ 192..192,
               168..168,
               0..254,
               1..254 ]
    ip = ""
    for x in 1..4 do
      ip += octets[x-1].to_a[rand(octets[x-1].count)].to_s
      ip += "." if x != 4
    end
    ip
  end

################################################################################

  def generate_mac
    digits = [ %w( 0 ),
               %w( 0 ),
               %w( 0 ),
               %w( 0 ),
               %w( 5 ),
               %w( e ),
               %w( 0 1 2 3 4 5 6 7 8 9 a b c d e f ),
               %w( 0 1 2 3 4 5 6 7 8 9 a b c d e f ),
               %w( 5 6 7 8 9 a b c d e f ),
               %w( 3 4 5 6 7 8 9 a b c d e f ),
               %w( 0 1 2 3 4 5 6 7 8 9 a b c d e f ),
               %w( 0 1 2 3 4 5 6 7 8 9 a b c d e f ) ]
    mac = ""
    for x in 1..12 do
      mac += digits[x-1][rand(digits[x-1].count)]
      mac += ":" if (x.modulo(2) == 0) && (x != 12)
    end
    mac
  end

################################################################################

end

################################################################################
