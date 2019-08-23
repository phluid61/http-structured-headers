
module StructuredHeaders
  class ByteSequence
    include SH::Item

    def initialize string
      @string = (+"#{string}").b
    end
    attr_reader :string

    def to_s
      @string.dup
    end

    def inpect
      "#<#{@string.each_byte.map{|b| '%02X' % b }}>"
    end
  end
end

