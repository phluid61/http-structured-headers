require_relative 'core'

# http://philzimmermann.com/docs/human-oriented-base-32-encoding.txt
module ZBase32
  class <<self
    include Base32Core

    PADDING = nil

    DICT = %w[y b n d r f g 8 e j k m c p q x o t 1 u w i s z a 3 4 5 h 7 6 9]
    RDICT = Hash[DICT.each_with_index.to_a]

    def decode32 str
      # ignore padding, invalid chars
      return '' if str.empty?
      str = str.gsub(/[^a-km-uw-z13-9]+/, '').b
      bin, pad = _decode32(str)
      warn 'detected non-zero padding bits' unless pad =~ /\A0*\z/
      bin
    end

    def encode32 bin
      # wrap at 60
      strict = strict_encode32(bin)
      strict.scan(/.{1,60}/).map{|line| "#{line}\n" }.join
    end

    def strict_decode32 str
      return '' if str.empty?
      raise ArgumentError, 'invalid z-base-32' unless str =~ /\A[a-km-uw-z13-9]+\z/
      bin, pad = _decode32(str)
      raise ArgumentError, 'invalid base32 (non-zero padding bits)' unless pad =~ /\A0*\z/
      bin
    end

    def strict_encode32 bin
      _encode32(bin)
    end
  end
end
