
require 'base64'

module StructuredFields

  module Serializer
    COMMA  = (+',').force_encoding(Encoding::US_ASCII).freeze
    WS     = (+' ').force_encoding(Encoding::US_ASCII).freeze
    DQUOTE = (+'"').force_encoding(Encoding::US_ASCII).freeze
    AT     = (+'@').force_encoding(Encoding::US_ASCII).freeze
    PERCENT= (+'%').force_encoding(Encoding::US_ASCII).freeze

    def self::_coerce obj
      case obj
      when StructuredFields::Dictionary
        return [:dictionary, obj]
      when Hash
        return [:dictionary, StructuredFields::Dictionary.new(obj)]
      when StructuredFields::List
        return [:list, obj]
      when Array
        return [:list, StructuredFields::List.new(obj)]
      when StructuredFields::Item
        return [:item, obj]
      else
        return [:item, StructuredFields::Item.new(obj)]
      end
    end

    #
    # Given a structure defined in this specification, return an ASCII
    # string suitable for use in an HTTP field value.
    #
    def self::serialize obj
      _type, obj = _coerce(obj)

      return if (_type == :dictionary || _type == :list) && obj.empty?

      case _type
      when :list
        output_string = serialize_list(obj)
      when :dictionary
        output_string = serialize_dictionary(obj)
      when :item
        output_string = serialize_item(obj)
      else
        raise StructuredFields::SerializationError, "serialize: unknown type #{_type.inspect}"
      end

      output_string.b
    end

    #
    # Given an array of (member-value, parameters) tuples as input_list,
    # return an ASCII string suitable for use in an HTTP field value.
    #
    def self::serialize_list input_list
      output = StructuredFields::empty_string
      input_list.each_member.with_index do |member_value, _idx|
        if member_value.is_a? StructuredFields::InnerList
          output << serialize_inner_list(member_value)
        else
          output << serialize_item(member_value)
        end
        if _idx < (input_list.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    #
    # Given an array of (member-value, parameters) tuples as inner_list and
    # parameters as list_parameters, return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_inner_list inner_list
      output = (+'(').force_encoding(Encoding::US_ASCII)
      inner_list.each_member.with_index do |member_value, _idx|
        output << serialize_item(member_value)
        output << WS if _idx < (inner_list.length - 1)
      end
      output << ')'.b
      output << serialize_parameters(inner_list.parameters)
      output
    end

    #
    # Given an ordered dictionary as input_parameters (each member having
    # a param-name and a param-value), return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_parameters parameters
      output = StructuredFields::empty_string
      parameters.each_pair do |param_name, param_value|
        output << ';'.b
        output << serialize_key(param_name)
        if !param_value.is_a?(StructuredFields::Boolean) || param_value.false?
          output << '='.b
          output << serialize_bare_item(param_value)
        end
      end
      output
    end

    #
    # Given a key as input_key, return an ASCII string suitable for use in
    # a HTTP header value.
    #
    def self::serialize_key input_key
      input_key = StructuredFields::Key.new(input_key).value
      # 1. Convert input_key into a sequence of ASCII characters; if conversion fails, fail serialization.
      # 2. If input_key contains characters not in lcalpha, DIGIT, “_”, “-“, “.”, or “*” fail serialization.
      # 3. If the first character of input_key is not lcalpha or “*”, fail serialization.
      output = StructuredFields::empty_string
      output << input_key
      output
    end

    #
    # Given an ordered dictionary as input_dictionary (each member having
    # a member-name and a tuple value of (member-value, parameters)),
    # return an ASCII string suitable for use in an HTTP field value.
    #
    def self::serialize_dictionary input_dictionary
      output = StructuredFields::empty_string
      input_dictionary.each_member.with_index do |(member_key, member_value), _idx|
        output << serialize_key(member_key)
        if member_value.is_a?(StructuredFields::Boolean) && member_value.true?
          output << serialize_parameters(member_value.parameters)
        else
          output << '='.b
          if member_value.is_a? StructuredFields::InnerList
            output << serialize_inner_list(member_value)
          else
            output << serialize_item(member_value)
          end
        end
        if _idx < (input_dictionary.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    #
    # Given an item bare_item and parameters item_parameters as input,
    # return an ASCII string suitable for use in an HTTP field value.
    #
    def self::serialize_item input_item
      output = StructuredFields::empty_string
      output << serialize_bare_item(input_item)
      output << serialize_parameters(input_item.parameters)
      output
    end

    #
    # Given an item as input_item, return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_bare_item input_item
      case input_item
      when StructuredFields::Integer
        return serialize_integer(input_item)
      when StructuredFields::Decimal
        return serialize_decimal(input_item)
      when StructuredFields::String
        return serialize_string(input_item)
      when StructuredFields::Token
        return serialize_token(input_item)
      when StructuredFields::ByteSequence
        return serialize_byte_sequence(input_item)
      when StructuredFields::Boolean
        return serialize_boolean(input_item)
      when StructuredFields::Date
        return serialize_date(input_item)
      when StructuredFields::DisplayString
        return serialize_display_string(input_item)
      else
        raise StructuredFields::SerializationError, "serialize_item: unrecognised item #{input_item.inspect}"
      end
    end

    #
    # Given an integer as input_integer, return an ASCII string suitable
    # for use in an HTTP field value.
    #
    def self::serialize_integer input_integer
      raise StructuredFields::SerializationError, "serialize_integer: integer out of range" if input_integer.int < -999_999_999_999_999 || input_integer.int > 999_999_999_999_999
      output = StructuredFields::empty_string
      output << '-'.b if input_integer.negative?
      output << input_integer.abs.to_s(10)
      output
    end

    #
    # Given a decimal as input_decimal, return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_decimal input_decimal
      # 1. If input_decimal is not a decimal number, fail serialization.
      # 2. If input_decimal has more than three significant digits to the right of the decimal point, round it to three decimal places, rounding the final digit to the nearest value, or to the even value if it is equidistant.
      # 3. If input_decimal has more than 12 significant digits to the left of the decimal point after rounding, fail serialization.
      output = StructuredFields::empty_string
      output << '-'.b if input_decimal.negative?
      output << input_decimal.integer_part_s
      output << '.'.b
      if input_decimal.fractional_part.zero?
        output << '0'.b
      else
        output << input_decimal.fractional_part_s
      end
      output
    end

    #
    # Given a string as input_string, return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_string input_string
      # 1. Convert input_string into a sequence of ASCII characters; if conversion fails, fail serialization.
      raise StructuredFields::SerializationError, "serialize_string: invalid characters" if input_string.string =~ /[\x00-\x1f\x7f]/
      output = StructuredFields::empty_string << DQUOTE
      input_string.each_char do |char|
        if char == '\\' || char == '"'
          output << '\\'.b
        end
        output << char
      end
      output << DQUOTE
      output
    end

    #
    # Given a token as input_token, return an ASCII string suitable for
    # use in an HTTP field value.
    #
    def self::serialize_token input_token
      # 1. Convert input_token into a sequence of ASCII characters; if conversion fails, fail serialization.
      raise StructuredFields::SerializationError, "serialize_token: invalid characters" if input_token.string !~ %r{[A-Za-z*][!#$%'*+.^_`|~0-9A-Za-z:/-]*}
      output = StructuredFields::empty_string
      output << input_token.to_s
      output
    end

    #
    # Given a byte sequence as input_bytes, return an ASCII string
    # suitable for use in an HTTP field value.
    #
    def self::serialize_byte_sequence input_bytes
      # 1. If input_bytes is not a sequence of bytes, fail serialization.
      output = StructuredFields::empty_string
      output << ':'.b
      output << Base64.strict_encode64(input_bytes.to_s)
      output << ':'.b
      output
    end

    #
    # Given a Boolean as input_boolean, return an ASCII string suitable
    # for use in an HTTP field value.
    #
    def self::serialize_boolean input_boolean
      # 1. If input_boolean is not a boolean, fail serialization.
      output = StructuredFields::empty_string
      output << '?'
      output << '1' if input_boolean.true?
      output << '0' if input_boolean.false?
      output
    end

    #
    # Given a Date as input_date, return an ASCII string suitable for use
    # in an HTTP field value.
    #
    def self::serialize_date input_date
      output = StructuredFields::empty_string << AT
      output << serialize_integer(input_date)
      output
    end

    #
    # Given a sequence of Unicode code points as input_sequence, return an
    # ASCII string suitable for use in an HTTP field value.
    #
    def self::serialize_display_string input_sequence
      # 1. If input_sequence is not a sequence of Unicode code points, fail serialization.
      # 2. Let byte_array be the result of applying UTF-8 encoding (Section 3 of [UTF8]) to input_sequence. If encoding fails, fail serialization.
      encoded_string = StructuredFields::empty_string << PERCENT << DQUOTE
      input_sequence.each_byte do |byte|
        if byte == 0x25 || byte == 0x22 || (byte >= 0x00 && byte <= 0x1f) || (byte >= 0x7f && byte <= 0xff)
          encoded_byte = StructuredFields::empty_string << PERCENT
          encoded_byte << ('%02x' % byte)
          encoded_string << encoded_byte
        else
          encoded_string << byte.chr
        end
      end
    end
  end

end

