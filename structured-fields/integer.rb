
module StructuredFields
  class Integer
    include StructuredFields::Item

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

    def inspect
      "#<#{self.class.name}: #{@int.inspect}>"
    end
    alias to_s inspect
  end
end

