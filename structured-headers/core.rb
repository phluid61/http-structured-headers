
module StructuredHeaders
  SPEC_VERSION = '-10'

  class SerialisationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

end

SH = StructuredHeaders

