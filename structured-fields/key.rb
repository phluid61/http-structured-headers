
module StructuredFields
  class Key
    def initialize value
      if value.is_a? Symbol
        value = value.to_s.b.freeze
      else
        value = "#{value.to_str}".b.freeze
      end
      raise %{invalid key #{value.inspect}, must match: ( lcalpha / "*" ) *( lcalpha / DIGIT / "_" / "-" / "." / "*" )} if value !~ /\A[a-z*][a-z0-9_\-.*]*\z/
      @value = value
    end

    attr_reader :value
    alias to_s value
    alias to_str value

    def inspect
      @value.inspect
    end
  end
end

