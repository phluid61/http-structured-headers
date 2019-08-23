
module StructuredHeaders
  class String
    include SH::Item

    def self::match? str
      str =~ /\A([\x20-\x5B]|[\x5D-\x7E]|\\")*\z/
    end

    def initialize string
      @string = (+"#{string}").b
      raise %{invalid string #{string.inspect}} unless SH::String::match? @string
    end
    attr_reader :string

    def each_char
      @string.each_char {|c| yield c }
    end

    def to_s
      @string.dup
    end

    def inpect
      @string.inspect
    end
  end
end

