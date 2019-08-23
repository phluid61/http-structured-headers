
module StructuredHeaders
  class Float
    include SH::Item

    def initialize float
      float = float.to_f
      intpart = float.abs.to_i
      raise "float out of range #{float.inspect}" if intpart > 99_999_999_999_999

      digits = intpart == 0 ? 1 : (Math.log10(intpart).floor + 1)
      precis = 15 - digits

      @str = ("%.#{precis}f" % float).sub(/(?<=\d)0+\z/, '')
      @rat = Rational(@str)
    end
    attr_reader :float

    def to_r
      @rat
    end

    def negative?
      @rat.negative?
    end

    def abs
      @rat.abs
    end

    def integer_part
      @rat.abs.to_i
    end

    def fractional_part
      @rat.abs.remainder(1)
    end

    def to_s
      @str.dup
    end

    def inpect
      "#<#{@str}>"
    end
  end
end
