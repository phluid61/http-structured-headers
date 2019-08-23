
module StructuredHeaders
  class Token
    include SH::Item

    def initialize string
      @string = (+"#{string}").b
      raise %{invalid token #{string.inspect}, must match: ALPHA *( ALPHA / DIGIT / "_" / "-" / "." / ":" / "%" / "*" / "/" )} unless @string =~ /\A[A-Za-z][A-Za-z0-9_.:%*\/-]*\z/
    end
    attr_reader :string

    def to_s
      @string.dup
    end

    def inpect
      "#<#{@string.inspect}>"
    end
  end
end

