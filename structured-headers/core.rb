
module StructuredHeaders
  SPEC_VERSION = '-12'

  class SerialisationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

end

SH = StructuredHeaders

