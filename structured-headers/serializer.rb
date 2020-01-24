
require 'base64'

module StructuredHeaders

  module Serializer
    COMMA  = (+',').force_encoding(Encoding::US_ASCII).freeze
    WS     = (+' ').force_encoding(Encoding::US_ASCII).freeze
    DQUOTE = (+'"').force_encoding(Encoding::US_ASCII).freeze

    def self::_coerce obj
      case obj
      when SH::Dictionary
        return [:dictionary, obj]
      when Hash
        return [:dictionary, SH::Dictionary.new(obj)]
      when SH::List
        return [:list, obj]
      when Array
        return [:list, SH::List.new(obj)]
      when SH::Item
        return [:item, obj]
      else
        return [:item, SH::Item.new(obj)]
      end
    end

    #
    # Given a structure defined in this specification, return an ASCII
    # string suitable for use in a HTTP header value.
    #
    def self::serialize obj
      _type, obj = _coerce(obj)

      return if (_type == :dictionary || _type == :list) && obj.empty?

      case _type
      when :dictionary
        output_string = serialize_dictionary(obj)
      when :list
        output_string = serialize_list(obj)
      when :item
        output_string = serialize_item(obj)
      else
        raise SH::SerializationError, "serialize: unknown type #{_type.inspect}"
      end

      output_string.b
    end

    #
    # Given an array of (member-value, parameters) tuples as input_list,
    # return an ASCII string suitable for use in a HTTP header value.
    #
    def self::serialize_list input_list
      output = SH::empty_string
      input_list.each_member.with_index do |member_value, idx|
        if member_value.is_a? SH::InnerList
          output << serialize_inner_list(member_value)
        else
          output << serialize_item(member_value)
        end
        if idx < (input_list.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    #
    # Given an array of (member-value, parameters) tuples as inner_list and
    # parameters as list_parameters, return an ASCII string suitable for
    # use in a HTTP header value.
    #
    def self::serialize_inner_list inner_list
      output = (+'(').force_encoding(Encoding::US_ASCII)
      inner_list.each_member.with_index do |member_value, idx|
        output << serialize_item(member_value)
        output << WS if idx < (inner_list.length - 1)
      end
      output << ')'.b
      output << serialize_parameters(inner_list.parameters)
      output
    end

    #
    # Given an ordered dictionary as input_parameters (each member having
    # a param-name and a param-value), return an ASCII string suitable for
    # use in a HTTP header value.
    #
    def self::serialize_parameters parameters
      output = SH::empty_string
      parameters.each_pair do |param_name, param_value|
        output << ';'.b
        output << serialize_key(param_name)
        if !param_value.is_a?(SH::Boolean) || param_value.false?
          output << '='.b
          output << serialize_item(param_value)
        end
      end
      output
    end

    #
    # Given a key as input_key, return an ASCII string suitable for use in
    # a HTTP header value.
    #
    def self::serialize_key input_key
      input_key = SH::Key.new(input_key).value
      # if input_key is not a sequence of characters, or contains characters not in lcalpha,
      # DIGIT, "_", "-", ".", or "*", fail serialization -- impossible if it's an SH::Key
      output = SH::empty_string
      output << input_key
      output
    end

    #
    # Given an ordered dictionary as input_dictionary (each member having
    # a member-name and a tuple value of (member-value, parameters)),
    # return an ASCII string suitable for use in a HTTP header value.
    #
    def self::serialize_dictionary input_dictionary
      output = SH::empty_string
      input_dictionary.each_member.with_index do |(member_name, member_value), idx|
        output << serialize_key(member_name)
        if !member_value.is_a?(SH::Boolean) || member_value.false? || member_value.parameters?
          output << '='.b
          if member_value.is_a? SH::InnerList
            output << serialize_inner_list(member_value)
          else
            output << serialize_item(member_value)
          end
        end
        if idx < (input_dictionary.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    #
    # Given an item bare_item and parameters item_parameters as input,
    # return an ASCII string suitable for use in a HTTP header value.
    #
    def self::serialize_item input_item
      output = SH::empty_string
      output << serialize_bare_item(input_item)
      output << serialize_parameters(input_item.parameters)
      output
    end

    #
    # Given an item as input_item, return an ASCII string suitable for
    # use in a HTTP header value.
    #
    def self::serialize_bare_item input_item
      case input_item
      when SH::Integer
        return serialize_integer(input_item)
      when SH::Decimal
        return serialize_decimal(input_item)
      when SH::String
        return serialize_string(input_item)
      when SH::Token
        return serialize_token(input_item)
      when SH::Boolean
        return serialize_boolean(input_item)
      when SH::ByteSequence
        return serialize_byte_sequence(input_item)
      else
        raise SH::SerializationError, "serialize_item: unrecognised item #{input_item.inspect}"
      end
    end

    #
    # Given an integer as input_integer, return an ASCII string suitable
    # for use in a HTTP header value.
    #
    def self::serialize_integer input_integer
      raise SH::SerializationError, "serialize_integer: integer out of range" if input_integer.int < -999_999_999_999_999 || input_integer.int > 999_999_999_999_999
      output = SH::empty_string
      output << '-'.b if input_integer.negative?
      output << input_integer.abs.to_s(10)
      output
    end

    #
    # Given a decimal as input_decimal, return an ASCII string suitable for
    # use in a HTTP header value.
    #
    def self::serialize_decimal input_decimal
      output = SH::empty_string
      output << '-'.b if input_decimal.negative?
      output << input_decimal.integer_part.to_s
      raise SH::SerializationError, "serialize_decimal: too many digits in integer part" if input_decimal.integer_part.to_s.length > 12
      output << '.'.b
      if input_decimal.fractional_part.zero?
        output << '0'.b
      else
        output << input_decimal.fractional_part.round(3).to_s # FIXME: "rounding the final digit to the nearest value, or to the even value if it is equidistant"?
      end
      output
    end

    #
    # Given a string as input_string, return an ASCII string suitable for
    # use in a HTTP header value.
    #
    def self::serialize_string input_string
      raise SH::SerializationError, "serialize_string: invalid characters" if input_string.string =~ /[\x00-\x1f\x7f]/
      output = SH::empty_string
      output << DQUOTE
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
    # use in a HTTP header value.
    #
    def self::serialize_token input_token
      raise SH::SerializationError, "serialize_token: invalid characters" if input_token.string !~ %r{[!#$%'*+.^_`|~0-9A-Za-z:/-]}
      output = SH::empty_string
      output << input_token.to_s
      output
    end

    #
    # Given a byte sequence as input_bytes, return an ASCII string
    # suitable for use in a HTTP header value.
    #
    def self::serialize_byte_sequence input_bytes
      # check type -- not needed here
      output = SH::empty_string
      output << ':'.b
      output << Base64.strict_encode64(input_bytes.to_s)
      output << ':'.b
      output
    end

    #
    # Given a Boolean as input_boolean, return an ASCII string suitable
    # for use in a HTTP header value.
    #
    def self::serialize_boolean input_boolean
      # check type -- not needed here
      output = SH::empty_string
      output << '?'
      output << '1' if input_boolean.true?
      output << '0' if input_boolean.false?
      output
    end
  end

end

