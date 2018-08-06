
module Base32Core
  def _encode32 bin
    binary = bin.each_byte.map{|b| '%08b' % b }.join
    (binary+'0000').scan(/[01]{5}/).map{|s| singleton_class::DICT[s.to_i(2)] }.join
  end
  def _decode32 str
    pentets = str.each_char.map{|c| singleton_class::RDICT[c] or raise "invalid character #{c.inspect}" }
    binary = pentets.map{|p| '%05b' % p }.join
    bin = binary.scan(/[01]{1,8}/).reduce(+''.b) do |bin, s|
      if s.length == 8
        bin + s.to_i(2).chr
      else
        return [bin, s]
      end
    end
    [bin, -''.b]
  end
end

