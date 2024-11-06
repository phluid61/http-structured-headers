
module StructuredFields
  module Item
    include StructuredFields::Parameterised

    def self::new obj
      case obj
      when StructuredFields::Integer, StructuredFields::Decimal, StructuredFields::String, StructuredFields::Token, StructuredFields::Boolean, StructuredFields::ByteSequence
        return obj
      when ::Integer
        return StructuredFields::Integer.new obj
      when ::Numeric
        return StructuredFields::Decimal.new obj
      when ::String
        if StructuredFields::String.match? obj
          return StructuredFields::String.new obj
        else
          return StructuredFields::ByteSequence.new obj
        end
      when true, false
        return StructuredFields::Boolean.new obj
      when ::Symbol
        return StructuredFields::Token.new obj
      else
        raise "invalid Item #{obj.inspect}"
      end
    end
  end
end

