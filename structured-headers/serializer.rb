
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
      input_list.each_member.with_index do |(member, parameters), idx|
        if member.is_a? SH::InnerList
          mem_value = serialize_inner_list(member)
        else
          mem_value = serialize_item(member)
        end
        output << mem_value
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
      inner_list.each_member do |mem|
        value = serialize_item(mem)
        output << value
        output << WS unless inner_list.empty?
      end
      output << ')'.b
      output
    end

    def self::serialize_parameters parameters
      output = SH::empty_string
      parameters.each_pair do |param_name, param_value|
        output << ';'.b
        name = serialize_key(param_name)
        output << name
        if !param_value.nil?
          value = serialize_item(param_value)
          output << '='.b
          output << value
        end
      end
      output
    end

    def self::serialize_key input_key
      # if input_key is not a sequence of characters, or contains characters not allowed
      # in the ABNF for key, fail serialization -- impossible if it's an SH::Key
      output = SH::empty_string
      output << input_key.value
      output
    end

    def self::serialize_dictionary input_dictionary
      output = SH::empty_string
      input_dictionary.each_member.with_index do |(member_name, member_value, parameters), idx|
        name = serialize_key(member_name)
        output << name
        output << '='.b
        if member_value.is_a? SH::InnerList
          value = serialize_inner_list(member_value)
        else
          value = serialize_item(member_value)
        end
        output << value
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
      # check ranges -- not needed for SH::Integer
      output = SH::empty_string
      output << '-'.b if input_integer.negative?
      output << input_integer.abs.to_s(10)
      output
    end

    def self::serialize_float input_float
      # check ranges -- not needed for SH::Float
      output = SH::empty_string
      output << '-'.b if input_float.negative?
      output << input_float.integer_part.to_s(10)
      output << '.'.b
      output << input_float.fractional_part.to_f.to_s[2..-1]
      output
    end

    def self::serialize_string input_string
      # check chars -- not needed for SH::String
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
      # check chars -- not needed for SH::Token
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

