
module StructuredHeaders
  class Integer
    include SH::Item

    def initialize int
      @int = int.to_i
      raise "integer out of bounds #{int.inspect}" if @int < -999_999_999_999_999 || @int > 999_999_999_999_999
    end
    attr_reader :int

    def < oth
      @int < oth
    end

    def > oth
      @int > oth
    end

    def to_i
      @int
    end

    def negative?
      @int.negative?
    end

    def abs
      @int.abs
    end

    def inpect
      "#<#{@int.inspect}>"
    end
  end
end

