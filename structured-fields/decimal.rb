
module StructuredFields
  class Decimal
    include StructuredFields::Item

    def initialize decimal
      raw = Rational(decimal.is_a?(Float) ? decimal.to_s : decimal) # urgh
      raise "decimal out of range #{decimal.inspect}" if raw.to_i.abs > 999_999_999_999

      @to_s = ('%.3f' % raw.round(3, half: :even)).sub(/(?<=\d)0+\z/, '').freeze
      @to_r = Rational(@to_s)
      @to_f = @to_r.to_f
      @abs = @to_r.abs

      @to_s =~ /\A-?(\d+)\.(\d+)\z/
      a, b = $1, $2
      @integer_part_s = a.sub(/\A0+(?=\d)/, '').freeze
      @fractional_part_s = b.sub(/(?<=\d)0+\z/, '').freeze

      @integer_part = @integer_part_s.to_i
      @fractional_part = ('0.' + @fractional_part_s).to_f
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

