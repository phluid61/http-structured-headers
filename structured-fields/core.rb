
module StructuredFields
  SPEC_VERSION = 'RFC9651'

  class SerializationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

  def self::empty_string
    (+'').force_encoding(Encoding::US_ASCII)
  end
end

