
require 'base64'

module StructuredHeaders

  module Parser
    LEADING_OWS = /\A[\x20\x09]+/

    def self::_discard_leading_OWS input_string
      input_string.sub!(LEADING_OWS, '')
    end

    def self::_bytes_to_string bytes
      str = bytes.respond_to?(:to_str) ? bytes.to_str : bytes.to_s
      str = (+"#{str}").b
      raise SH::ParseError, "cannot convert non-ASCII bytes to ASCII: #{bytes.inspect}" unless str.ascii_only?
      str.encode!(Encoding::US_ASCII, Encoding::ASCII_8BIT)
    end

    ##
    # Given an array of bytes input_bytes that represents the chosen
    # header's field-value (which is an empty string if that header is not
    # present), and header_type (one of "dictionary", "list", or "item"),
    # return the parsed header value.
    #
    def self::parse input_bytes, header_type
      input_string = _bytes_to_string(input_bytes)
      _discard_leading_OWS(input_string)
      case header_type
      when 'list', :list
        output = parse_list(input_string)
      when 'dictionary', :dictionary
        output = parse_dictionary(input_string)
      when 'item', :item
        output = parse_item(input_string)
      #else
      #  raise SH::ParseError, "parse: unrecognised type #{header_type.inspect}"
      end
      _discard_leading_OWS(input_string)
      raise SH::ParseError, "parse: input_string is not empty: #{input_string.inspect}" unless input_string.empty?
      output
    end

    ##
    # Given an ASCII string input_string, return an array of (item_or_inner_list,
    # parameters) tuples. input_string is modified to remove the parsed value.
    #
    def self::parse_list input_string
      members = SH::List.new
      while !input_string.empty?
        members.append parse_item_or_inner_list(input_string)
        _discard_leading_OWS(input_string)
        return members if input_string.empty?
        raise SH::ParseError, "parse_list: expected comma after list member" if input_string.slice!(0) != ','
        _discard_leading_OWS(input_string)
        raise SH::ParseError, "parse_list: unexpected trailing comma" if input_string.empty?
      end
      members
    end

    ##
    # Given an ASCII string as input_string, return the tuple (item_or_inner_list,
    # parameters), where item_or_inner_list can be either a single bare
    # item, or an array of (bare_item, parameters) tuples. input_string
    # is modified to remove the parsed value.
    #
    def self::parse_item_or_inner_list input_string
      if input_string.slice(0) == '('
        parse_inner_list(input_string)
      else
        parse_item(input_string)
      end
    end

    ##
    # Given an ASCII string as input_string, return the tuple (inner_list,
    # parameters), where inner_list is an array of (bare_item, parameters)
    # tuples. input_string is modified to remove the parsed value.
    #
    def self::parse_inner_list input_string
      raise SH::ParseError, "parse_inner_list: missing open '('" if input_string.slice!(0) != '('
      inner_list = SH::InnerList.new
      while !input_string.empty?
        _discard_leading_OWS(input_string)
        if input_string.slice(0) == ')'
          input_string.slice!(0)
          inner_list.parameters = parse_parameters(input_string)
          return inner_list
        end
        item = parse_item(input_string)
        inner_list << item
        raise SH::ParseError, "parse_inner_list: expected space after item; got #{input_string.slice(0).inspect}" if input_string !~ /\A[\x20)]/
      end
      raise SH::ParseError, "parse_inner_list: the end of the inner list was not found"
    end

    ##
    # Given an ASCII string as input_string, return an ordered map whose
    # values are (item_or_inner_list, parameters) tuples. input_string
    # is modified to remove the parsed value.
    #
    def self::parse_dictionary input_string
      dictionary = SH::Dictionary.new
      while !input_string.empty?
        this_key = parse_key(input_string)
        raise SH::ParseError, "parse_dictionary: duplicate key #{this_key.inspect}" if dictionary.key? this_key
        raise SH::ParseError, "parse_dictionary: expected '=' after key" if input_string.slice!(0) != '='
        member = parse_item_or_inner_list(input_string)
        dictionary.set this_key, member
        _discard_leading_OWS(input_string)
        return dictionary if input_string.empty?
        raise SH::ParseError, "parse_dictionary: expected ',' after value" if input_string.slice!(0) != ','
        _discard_leading_OWS(input_string)
        raise SH::ParseError, "parse_dictionary: trailing comma" if input_string.empty?
      end
      dictionary
    end

    ##
    # Given an ASCII string as input_string, return a (bare_item,
    # parameters) tuple. input_string is modified to remove the parsed
    # value.
    #
    def self::parse_item input_string
      bare_item = parse_bare_item(input_string)
      bare_item.parameters = parse_parameters(input_string)
      bare_item
    end

    ##
    # Given an ASCII string as input_string, return a bare item.
    # input_string is modified to remove the parsed value.
    #
    def self::parse_bare_item input_string
      case input_string.slice(0)
      when /\A[-0-9]/
        parse_number(input_string)
      when '"'
        parse_string(input_string)
      when '*'
        parse_byte_sequence(input_string)
      when '?'
        parse_boolean(input_string)
      when /\A[A-Za-z]/
        parse_token(input_string)
      else
        raise SH::ParseError, "parse_item: unknown item #{input_string.inspect}"
      end
    end

    ##
    # Given an ASCII string as input_string, return an ordered map whose
    # values are bare items. input_string is modified to remove the
    # parsed value.
    #
    def self::parse_parameters input_string
      parameters = SH::Parameters.new
      while !input_string.empty?
        _discard_leading_OWS(input_string)
        break if input_string.slice(0) != ';'
        input_string.slice!(0)
        _discard_leading_OWS(input_string)
        param_name = parse_key(input_string)
        raise "parse_parameters: duplicate key in parameters #{param_name.inspect}" if parameters.key? param_name
        param_value = nil
        if input_string.slice(0) == '='
          input_string.slice!(0)
          param_value = parse_bare_item(input_string)
        end
        parameters.set param_name, param_value
      end
      parameters
    end

    ##
    # Given an ASCII string as input_string, return a key. input_string
    # is modified to remove the parsed value.
    #
    def self::parse_key input_string
      raise SH::ParseError, "parse_key: first character not lcalpha #{input_string.slice(0).inspect}" if input_string !~ /\A[a-z]/
      output_string = SH::empty_string
      while !input_string.empty?
        return SH::Key.new(output_string) if input_string.slice(0) !~ /\A[a-z0-9*_-]/
        char = input_string.slice!(0)
        output_string << char
      end
      SH::Key.new(output_string)
    end

    ##
    # Given an ASCII string input_string, return a number. input_string is
    # modified to remove the parsed value.
    #
    # NOTE: This algorithm parses both Integers (Section 3.3.1) and Floats
    # (Section 3.3.2), and returns the corresponding structure.
    #
    def self::parse_number input_string
      type = :integer
      sign = 1
      input_number = SH::empty_string
      if input_string.slice(0) == '-'
        input_string.slice!(0)
        sign = -1
      end
      raise SH::ParseError, "parse_number: no digits" if input_string.empty?
      raise SH::ParseError, "parse_number: not a digit #{input_string.slice(0).inspect}" if input_string !~ /\A[0-9]/
      while !input_string.empty?
        char = input_string.slice!(0)
        if char =~ /\A[0-9]/
          input_number << char
        elsif type == :integer && char == '.'
          input_number << char
          type = :float
        else
          input_string.replace(char + input_string)
          break
        end
        raise SH::ParseError, "parse_number: integer too long #{input_number}" if type == :integer && input_number.length > 15
        raise SH::ParseError, "parse_number: float too long #{input_number}" if type == :float && input_number.length > 16
      end
      if type == :integer
        output_number = SH::Integer.new(input_number.to_i(10) * sign)
        raise SH::ParseError, "parse_number: output_number #{output_number} too large" if output_number < -999_999_999_999_999 || output_number > 999_999_999_999_999
      else
        raise SH::ParseError, "parse_number: trailing decimal point in #{input_number}" if input_number =~ /\.\z/
        raise SH::ParseError, "parse_number: too many digits after decimal point in #{input_numer}" if input_number =~ /\.\d{7}/
        output_number = SH::Float.new(input_number.to_f * sign)
      end
      output_number
    end

    ##
    # Given an ASCII string input_string, return an unquoted string.
    # input_string is modified to remove the parsed value.
    #
    def self::parse_string input_string
      output_string = SH::empty_string
      raise SH::ParseError, "parse_string: missing open '\"'" if input_string.slice(0) != '"'
      input_string.slice!(0)
      while !input_string.empty?
        char = input_string.slice!(0)
        if char == '\\'
          if input_string.empty?
            raise SH::ParseError, "parse_string: unterminated string"
          else
            next_char = input_string.slice!(0)
            raise SH::ParseError, "parse_string: invalid escape sequence #{next_char.inspect}" if next_char !~ /\A["\\]/
            output_string << next_char
          end
        elsif char == '"'
          return SH::String.new(output_string)
        elsif char =~ /\A[\x00-\x1F\x7F]/
          raise SH::ParseError, "parse_string: invalid character #{char.inspect}"
        else
          output_string << char
        end
      end
      raise SH::ParseError, "parse_string: reached end of input_string without finding closing DQUOTE"
    end

    ##
    # Given an ASCII string input_string, return a token. input_string is
    # modified to remove the parsed value.
    #
    def self::parse_token input_string
      raise SH::ParseError, "parse_token: first character not ALPHA #{input_string.slice(0).inspect}" if input_string !~ /\A[A-Za-z]/
      output_string = SH::empty_string
      while !input_string.empty?
        return SH::Token.new(output_string) if input_string !~ %r{\A[A-Za-z0-9_.:%*/-]}
        char = input_string.slice!(0)
        output_string << char
      end
      SH::Token.new(output_string)
    end

    #
    # Because some implementations of base64 do not allow reject of encoded
    # data that is not properly "=" padded (see [RFC4648], Section 3.2),
    # parsers SHOULD NOT fail when it is not present, unless they cannot be
    # configured to do so.
    #
    # Because some implementations of base64 do not allow rejection of
    # encoded data that has non-zero pad bits (see [RFC4648], Section 3.5),
    # parsers SHOULD NOT fail when it is present, unless they cannot be
    # configured to do so.
    #
    # This specification does not relax the requirements in [RFC4648],
    # Section 3.1 and 3.3; therefore, parsers MUST fail on characters
    # outside the base64 alphabet, and on line feeds in encoded data.
    #
    def self::_base64_decode64 str
      raise ParseError, "not Base64" if str !~ /\A[A-Z0-9+\/]*=*\z/i # has to look mostly right...
      Base64.decode64(str) # ...but we're not going to cry over it
    end

    ##
    # Given an ASCII string input_string, return a byte sequence.
    # input_string is modified to remove the parsed value.
    #
    def self::parse_byte_sequence input_string
      raise SH::ParseError, "parse_byte_sequence: missing open '*'" if input_string.slice(0) != '*'
      input_string.slice!(0)
      raise SH::ParseError, "parse_byte_sequence: missing final '*'" unless (_idx = input_string.index('*'))
      b64_content = input_string.slice!(0, _idx)
      input_string.slice!(0)
      raise SH::ParseError, "parse_byte_sequence: non-base-64 characters in #{b64_content.inspect}" if b64_content !~ /\A[A-Za-z0-9+\/=]*\z/
      binary_content = _base64_decode64(b64_content)
      SH::ByteSequence.new(binary_content)
    end

    ##
    # Given an ASCII string input_string, return a Boolean. input_string is
    # modified to remove the parsed value.
    #
    def self::parse_boolean input_string
      raise SH::ParseError, "parse_boolean: missing initial '?'" if input_string.slice(0) != '?'
      input_string.slice!(0)
      if input_string.slice(0) == '1'
        input_string.slice!(0)
        return SH::Boolean.new(true)
      end
      if input_string.slice(0) == '0'
        input_string.slice!(0)
        return SH::Boolean.new(false)
      end
      raise SH::ParseError, "parse_boolean: invalid boolean character #{input_string.slice(0).inspect}, expected '1' or '0'"
    end
  end

end

