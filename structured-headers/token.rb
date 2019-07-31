
require_relative 'core'

module StructuredHeaders
  class Token
    def initialize string
      @string = (+"#{string}").b
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

