
module StructuredHeaders
  SPEC_VERSION = '-12'

  class SerializationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

  def self::empty_string
    (+'').force_encoding(Encoding::US_ASCII)
  end

end

SH = StructuredHeaders

