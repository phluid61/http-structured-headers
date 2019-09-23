
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

    def self::serialize_list input_list
      output = SH::empty_string
      input_list.each_member.with_index do |(member_value, parameters), idx|
        if member_value.is_a? SH::InnerList
          output << serialize_inner_list(member_value)
        else
          output << serialize_item(member_value)
        end
        output << serialize_parameters(parameters)
        if idx < (input_list.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    def self::serialize_inner_list inner_list
      output = (+'(').force_encoding(Encoding::US_ASCII)
      inner_list.each_member.with_index do |member_value, idx|
        output << serialize_item(member_value)
        output << WS if idx < (inner_list.length - 1)
      end
      output << ')'.b
      output
    end

    def self::serialize_parameters parameters
      output = SH::empty_string
      parameters.each_pair do |param_name, param_value|
        output << ';'.b
        output << serialize_key(param_name)
        if !param_value.nil?
          output << '='.b
          output << serialize_item(param_value)
        end
      end
      output
    end

    def self::serialize_key input_key
      input_key = SH::Key.new(input_key).value
      # if input_key is not a sequence of characters, or contains characters not in lcalpha,
      # DIGIT, "*", "_", or "-", fail serialization -- impossible if it's an SH::Key
      output = SH::empty_string
      output << input_key
      output
    end

    def self::serialize_dictionary input_dictionary
      output = SH::empty_string
      input_dictionary.each_member.with_index do |(member_name, member_value, parameters), idx|
        output << serialize_key(member_name)
        output << '='.b
        if member_value.is_a? SH::InnerList
          output << serialize_inner_list(member_value)
        else
          output << serialize_item(member_value)
        end
        output << serialize_parameters(parameters)
        if idx < (input_dictionary.length - 1)
          output << COMMA
          output << WS
        end
      end
      output
    end

    def self::serialize_item input_item
      case input_item
      when SH::Integer
        return serialize_integer(input_item)
      when SH::Float
        return serialize_float(input_item)
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

    def self::serialize_integer input_integer
      raise SH::SerializationError, "serialize_integer: integer out of range" if input_integer.int < -999_999_999_999_999 || input_integer.int > 999_999_999_999_999
      output = SH::empty_string
      output << '-'.b if input_integer.negative?
      output << input_integer.abs.to_s(10)
      output
    end

    def self::serialize_float input_float
      output = SH::empty_string
      output << '-'.b if input_float.negative?
      output << input_float.integer_part_s
      integer_digits = input_float.integer_part_s.length
      raise SH::SerializationError, "serialize_float: too many digits in integer part" if integer_digits > 14
      digits_avail = 15 - integer_digits
      fractional_digits_avail = [digits_avail, 6].min
      output << '.'.b
      output << input_float.fractional_part_s[0..fractional_digits_avail]
      output
    end

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

    def self::serialize_token input_token
      raise SH::SerializationError, "serialize_token: invalid characters" if input_token.string !~ /[A-Za-z0-9_.:%*-]/
      output = SH::empty_string
      output << input_token.to_s
      output
    end

    def self::serialize_byte_sequence input_bytes
      # check type -- not needed here
      output = SH::empty_string
      output << '*'.b
      output << Base64.strict_encode64(input_bytes.to_s)
      output << '*'.b
      output
    end

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

