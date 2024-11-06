
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
      @string.dup
    end

    def inpect
      @string.inspect
    end
  end
end


