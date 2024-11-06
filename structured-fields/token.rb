
module StructuredFields
  class Token
    include StructuredFields::Item

    def initialize string
      @string = (+"#{string}").b
      raise %{invalid token #{string.inspect}, must match: (ALPHA / "*") *(tchar / ":" / "/")} unless @string =~ %r{\A[A-Za-z*][!#$%&'*+.^_`|~0-9A-Za-z:/-]*\z}
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

