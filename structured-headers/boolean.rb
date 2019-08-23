
module StructuredHeaders
  class Boolean
    include SH::Item

    def initialize bool
      @bool = !!bool
    end
    attr_reader :bool

    def true?
      @bool
    end

    def false?
      !@bool
    end

    def to_s
      @bool ? '?1' : '?0'
    end

    def inpect
      "#<#{to_s}>"
    end
  end
end

