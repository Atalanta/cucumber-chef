module Cucumber::Chef::Helpers::Utility

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

end
