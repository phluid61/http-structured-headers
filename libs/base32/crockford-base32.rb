require_relative 'core'

# http://www.crockford.com/wrmg/base32.html
module CrockfordBase32
  class <<self
    include Base32Core

    PADDING = nil

    DICT = %w[0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T V W X Y Z]
    RDICT = Hash[DICT.each_with_index.to_a]

    CHECK = DICT + %w[* ~ $ = U]
    RCHECK = Hash[CHECK.each_with_index.to_a]

    def decode32 str, checksum=false
      # ignore padding, invalid chars
      return '' if str.empty?
      return '' if str == '0'
      str = str.b.upcase.gsub('-','').gsub('O','0').gsub(/[IL]/,'1')
      if checksum == :detect
        if str.sub!(/([*~$=U])\Z/, '')
          checksum = RCHECK[$1]
        end
      elsif checksum
        str.sub!(/(.)\Z/, '')
        checksum = RCHECK[$1]
      end
      str = str.gsub(/[^0-9A-HJKMNP-TV-Z]+/, '')

      bin, pad = _decode32(str)
      warn 'detected non-zero padding bits' unless pad =~ /\A0*\z/

      if checksum
        checkvalue = bin.each_byte.reduce(0){|sum, byte| (sum + byte) % 37 }
        raise ArgumentError, "bad checksum in crockford-base32 data (got #{checkvalue}, expected #{checksum})" if checkvalue != checksum
      end

      bin
    end

    def encode32 bin, checksum=false
      # insert hyphens every 8 characters
      strict = strict_encode32(bin, checksum)
      strict.scan(/.{1,8}/).join('-')
    end

    def strict_decode32 str, checksum=false
      return '' if str.empty?
      return '' if str == '0'
      str = str.b.upcase.gsub('-','').gsub('O','0').gsub(/[IL]/,'1')
      if checksum == :detect
        if str.sub!(/([*~$=U])\Z/, '')
          checksum = RCHECK[$1]
        end
      elsif checksum
        str.sub!(/(.)\Z/, '')
        checksum = RCHECK[$1]
      end
      raise ArgumentError, 'invalid crockford-base32' unless str =~ /\A[0-9A-HJKMNP-TV-Z]+\z/

      bin, pad = _decode32(str)
      raise ArgumentError, 'invalid crockford-base32 (non-zero padding bits)' unless pad =~ /\A0*\z/

      if checksum
        checkvalue = bin.each_byte.reduce(0){|sum, byte| (sum + byte) % 37 }
        raise ArgumentError, "bad checksum in crockford-base32 data (got #{checkvalue}, expected #{checksum})" if checkvalue != checksum
      end

      bin
    end

    def strict_encode32 bin, checksum=false
      str = _encode32(bin)

      if checksum
        checkvalue = bin.each_byte.reduce(0){|sum, byte| (sum + byte) % 37 }
        str += CHECK[checkvalue]
      end

      str
    end
  end
end
