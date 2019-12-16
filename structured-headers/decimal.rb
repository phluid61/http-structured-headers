
module StructuredHeaders
  class Decimal
    include SH::Item

    def initialize decimal
      float = decimal.to_f
      raise "decimal out of range #{decimal.inspect}" if float.to_i > 999_999_999_999

      @to_s = ('%.3f' % float).sub(/(?<=\d)0+\z/, '').freeze
      @to_r = Rational(@to_s)
      @to_f = @to_r.to_f
      @abs = @to_r.abs

      @to_s =~ /\A-?(\d+)\.(\d+)\z/
      a, b = $1, $2
      @integer_part_s = a.sub(/\A0+(?=\d)/, '').freeze
      @fractional_part_s = b.sub(/(?<=\d)0+\z/, '').freeze

      @integer_part = @integer_part_s.to_i
      @fractional_part = @fractional_part_s.to_i
    end
    attr_reader :to_s, :to_r, :to_f, :abs
    attr_reader :integer_part, :integer_part_s
    attr_reader :fractional_part, :fractional_part_s

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

