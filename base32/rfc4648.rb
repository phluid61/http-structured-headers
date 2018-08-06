require_relative 'core'

# https://tools.ietf.org/html/rfc4648#section-6
module Base32
  class <<self
    include Base32Core

    PADDING = '='

    DICT = %w[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 2 3 4 5 6 7]
    RDICT = Hash[DICT.each_with_index.to_a]

    def decode32 str
      # ignore padding, invalid chars
      return '' if str.empty?
      str = str.gsub(/[^A-Z2-7]+/, '').b
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
      raise ArgumentError, 'invalid base32' unless (str.bytesize % 8).zero?
      raise ArgumentError, 'invalid base32' unless str =~ /\A[A-Z2-7]+={0,7}\z/
      str = str.b.sub(/=+\z/, '')
      bin, pad = _decode32(str)
      raise ArgumentError, 'invalid base32 (non-zero padding bits)' unless pad =~ /\A0*\z/
      bin
    end

    def strict_encode32 bin
      str = _encode32(bin)
      if str.length % 8 != 0
        pad = '=' * (8 - (str.length % 8))
      else
        pad = ''
      end
      str + pad
    end
  end
end
