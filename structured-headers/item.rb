
module StructuredHeaders
  module Item
    include SH::Parameterised

    def self::new obj
      case obj
      when SH::Integer, SH::Float, SH::String, SH::Token, SH::Boolean, SH::ByteSequence
        return obj
      when ::Integer
        return SH::Integer.new obj
      when ::Numeric
        return SH::Float.new obj
      when ::String
        if SH::String.match? obj
          return SH::String.new obj
        else
          return SH::ByteSequence.new obj
        end
      when true, false
        return SH::Boolean.new obj
      when ::Symbol
        return SH::Token.new obj
      else
        raise "invalid Item #{obj.inspect}"
      end
    end
  end
end

