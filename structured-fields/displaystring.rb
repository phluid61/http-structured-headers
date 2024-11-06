
module StructuredFields
  class DisplayString
    include StructuredFields::Item

    def initialize string
      @string = (+"#{string}").encode(Encoding::UTF_8)
    end
    attr_reader :string

    def each_byte
      @string.each_byte {|b| yield b }
    end

    def to_s
      str = each_byte.map{|b| b == 0x25 || b == 0x22 || (b >= 0x00 && b <= 0x1f) || (b >= 0x7f && b <= 0xff) ? ('%%%02x' % b) : b.chr }
      "%\"#{str}\""
    end

    def inpect
      @string.inspect
    end
  end
end


