
module StructuredHeaders
  class Decimal
    include SH::Item

    def initialize decimal
      float = decimal.to_f
      @to_s = ('%.3f' % float).sub(/(?<=\d)0+\z/, '').freeze
      @to_r = Rational(@to_s)
      @to_f = @to_r.to_f
      @abs = @to_r.abs

      @integer_part = @abs.to_i
      @fractional_part = @abs - @integer_part

      raise "decimal out of range #{decimal.inspect}" if @integer_part > 999_999_999_999
    end
    attr_reader :to_s, :to_r, :to_f, :abs, :integer_part, :fractional_part

    def < oth
      @to_r < oth
    end

    def > oth
      @to_r > oth
    end

    def negative?
      @to_r.negative?
    end

    def inpect
      "#<#{@to_s}>"
    end
  end
end

