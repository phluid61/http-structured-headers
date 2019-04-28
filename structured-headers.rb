
require 'base64'

module StructuredHeaders

  class SerialisationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

  class ParameterisedToken
    def initialize token, parameters={}
      @token = token
      @parameters = parameters
    end
    attr_reader :token, :parameters

    def each_parameter
      return enum_for(:each_parameter) unless block_given?
      @parameters.each { |parameter| yield parameter }
      self
    end

    def []= key, value
      @parameters[key] = value
    end

    def to_s
      "\#<#{self.class.name}:#{@token.inspect}#{@parameters.map{|k,v|";#{k.inspect}=#{v.inspect}"}.join}>"
    end
    alias inspect to_s
  end

  class ByteSequence
    def initialize string
      @string = (+"#{string}").b
    end
    attr_reader :string

    def to_s
      @string.dup
    end

    def inspect
      "#<#{@string.inspect}>"
    end
  end

  class Token
    def initialize string
      @string = (+"#{string}").b
    end
    attr_reader :string

    def to_s
      @string.dup
    end

    def inspect
      "#<#{@string.inspect}>"
    end
  end

  def self::_empty_string
    (+'').force_encoding(Encoding::ASCII)
  end

  def self::_base64_decode64 str
    raise ParseError, "not Base64" if str !~ /\A[A-Z0-9+\/]*=*\z/i # has to look mostly right...
    Base64.decode64(str) # ...but we're not going to cry over it
  end

  # --------------------------------------------------

  SERIALISE_STRING = /\A([\x20-\x5B]|[\x5D-\x7E]|\\")*\z/
  SERIALISE_TOKEN = /\A[A-Za-z][A-Za-z0-9_.:%*\/-]*\z/
  SERIALISE_KEY        = /\A[a-z][a-z0-9_-]*\z/

  def self::serialise_header obj, type
    case type
    when 'dictionary'
      serialise_dictionary(obj)
    when 'param-list'
      serialise_parameterised_list(obj)
    when 'list-list'
      serialise_listlist(obj)
    when 'list'
      serialise_list(obj)
    when 'item'
      serialise_item(obj)
    else
      raise ArgumentError, "unable to serialise #{type.inspect}"
    end
  end

  def self::serialise_dictionary input_dictionary
    output = _empty_string
    input_dictionary.each_with_index do |mem, _idx|
      member_name, member_value = mem

      name = serialise_key(member_name)
      output << name
      output << '='
      value = serialise_item(member_value)
      output << value
      if _idx < (input_dictionary.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::serialise_key input_key
    input_key = input_key.to_s

    raise SerialisationError, "key contains invalid characters #{input_key.inspect}" if input_key !~ SERIALISE_KEY
    output = _empty_string
    output << input_key
    output
  end

  def self::serialise_list input_list
    output = _empty_string
    input_list.each_with_index do |mem, _idx|
      value = serialise_item(mem)
      output << value
      if _idx < (input_list.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::serialise_listlist input_list
    output = _empty_string
    input_list.each_with_index do |inner_list, _idx|
      raise SerialisationError, "inner_list is not a list #{inner_list.inspect}" unless inner_list.respond_to? :each_with_index
      raise SerialisationError, "inner_list is empty" if inner_list.empty?
      inner_list.each_with_index do |inner_mem, _inner_idx|
        value = serialise_item(inner_mem)
        output << value
        if _inner_idx < (inner_list.length - 1)
          output << ';'
          output << ' '
        end
      end
      if _idx < (input_list.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::serialise_parameterised_list input_plist
    output = _empty_string
    input_plist.each_with_index do |mem, _idx|
      id = serialise_token(mem.token)
      output << id
      mem.each_parameter do |parameter|
        param_name, param_value = parameter

        output << ';'
        name = serialise_key(param_name)
        output << name
        if param_value
          value = serialise_item(param_value)
          output << '='
          output << value
        end
      end
      if _idx < (input_plist.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::_typeof item
    case item
    when Integer
      :integer
    when Numeric
      :float
    when String
      if item =~ SERIALISE_STRING
        :string
      else
        :byte_sequence
      end
    when ByteSequence
      :byte_sequence
    when true, false
      :boolean
    when Symbol, Token
      :token
    end
  end

  def self::serialise_item input_item
    _type = _typeof(input_item) # defaults to 'nil'
    case _type
    when :integer
      serialise_integer(input_item)
    when :float
      serialise_float(input_item)
    when :string
      serialise_string(input_item)
    when :token
      serialise_token(input_item)
    when :boolean
      serialise_boolean(input_item)
    when :byte_sequence
      serialise_byte_sequence(input_item)
    else
      raise SerialisationError, "not a valid 'item' type: #{item.class.name}"
    end
  end

  def self::serialise_integer input_integer
    input_integer = input_integer.to_i
    raise SerialisationError, "integer #{input_integer.inspect} out of bounds" if input_integer < -9_223_372_036_854_775_808 || input_integer > 9_223_372_036_854_775_807
    output = _empty_string
    output << '-' if input_integer < 0
    output << input_integer.abs.to_s(10)
    output
  end

  def self::serialise_float input_float
    input_float = input_float.to_f
    output = _empty_string
    output << '-' if input_float < 0
    output << input_float.abs.to_s # !!! uh... close enough
    output
  end

  def self::serialise_string input_string
    input_string = input_string.to_s

    raise SerialisationError, "string contains invalid characters #{input_string.inspect}" if input_string !~ SERIALISE_STRING # FIXME: this literally says "VCHAR or SP"
    output = _empty_string
    output << '"'
    input_string.each_char do |char|
      output << '\\' if char == '\\' || char == '"'
      output << char
    end
    output << '"'
    output
  end

  def self::serialise_token input_token
    input_token = input_token.to_s

    raise SerialisationError, "token contains invalid characters #{input_token.inspect}" if input_token !~ SERIALISE_TOKEN
    output = _empty_string
    output << input_token
    output
  end

  def self::serialise_byte_sequence input_bytes
    input_bytes = input_bytes.to_s.b

    output = _empty_string
    output << '*'
    output << Base64.strict_encode64(input_bytes)
    output << '*'
    output
  end

  def self::serialise_boolean input
    #raise SerialisationError if input is not boolean # everything in Ruby is boolean
    output = _empty_string
    output << '?'
    output << '1' if input
    output << '0' if !input
    output
  end

  # --------------------------------------------------

  LEADING_OWS = /\A[\x20\x09]+/

  def self::_discard_leading_OWS input_string
    input_string.sub!(LEADING_OWS, '')
  end

  def self::parse_header input_string, header_type
    if !input_string.respond_to?(:to_str) && input_string.respond_to?(:map)
      input_string = input_string.map{|s| s.to_s }.join(',')
    end
    input_string = "#{input_string}".encode('US-ASCII')

    _discard_leading_OWS input_string
    case header_type.to_s
    when 'dictionary'
      output = parse_dictionary(input_string)
    when 'list'
      output = parse_list(input_string)
    when 'list-list'
      output = parse_listlist(input_string)
    when 'param-list'
      output = parse_parameterised_list(input_string)
    when 'item'
      output = parse_item(input_string)
    #XXX doesn't warn/error on bad header_type
    end
    _discard_leading_OWS input_string
    raise ParseError, "input_string should be empty #{input_string.inspect}" unless input_string.empty?
    output
  end

  def self::parse_dictionary input_string
    dictionary = {}
    until input_string.empty?
      this_key = parse_key(input_string)
      raise ParseError, "repeated dictionary key #{this_key.inspect}" if dictionary.key? this_key
      raise ParseError, "dictionary missing '=' for key #{this_key.inspect}" if input_string.slice!(0) != '='
      this_value = parse_item(input_string)
      dictionary[this_key] = this_value
      _discard_leading_OWS(input_string)
      return dictionary if input_string.empty?
      raise ParseError, "dictionary missing comma after #{this_key.inspect}" if input_string.slice!(0) != ','
      _discard_leading_OWS(input_string)
      raise ParseError, "unexpected trailing comma in dictionary" if input_string.empty?
    end
    raise ParseError, "No structured data has been found"
  end

  def self::parse_key input_string
    raise "key should start with lcalpha #{input_string.inspect}" if input_string.slice(0) !~ /[a-z]/
    output_string = _empty_string
    until input_string.empty?
      char = input_string.slice!(0)
      if char !~ /[a-z0-9_-]/
        input_string.replace(char + input_string)
        return output_string
      end
      output_string << char
    end
    output_string
  end

  def self::parse_list input_string
    items = []
    until input_string.empty?
      item = parse_item(input_string)
      items << item
      _discard_leading_OWS(input_string)
      return items if input_string.empty?
      raise ParseError, "list missing comma after #{item.inspect}" if input_string.slice!(0) != ','
      _discard_leading_OWS(input_string)
      raise ParseError, "unexpected trailing comma in list" if input_string.empty?
    end
    raise ParseError, "No structured data has been found"
  end

  def self::parse_listlist input_string
    top_list = []
    inner_list = []
    until input_string.empty?
      item = parse_item(input_string)
      inner_list << item
      _discard_leading_OWS(input_string)
      if input_string.empty?
        top_list << inner_list
        return top_list
      end
      char = input_string.slice!(0)
      if char == ','
        top_list << inner_list
        inner_list = []
      elsif char != ';'
        raise ParseError, "list missing semicolon after #{item.inspect}"
      end
      _discard_leading_OWS(input_string)
      raise ParseError, "unexpected trailing separator in list" if input_string.empty?
    end
    raise ParseError, "No structured data has been found"
  end

  def self::parse_parameterised_list input_string
    items = []
    until input_string.empty?
      item = parse_parameterised_token(input_string)
      items << item
      _discard_leading_OWS(input_string)
      return items if input_string.empty?
      raise ParseError, "list missing comma after #{item.inspect}" if input_string.slice!(0) != ','
      _discard_leading_OWS(input_string)
      raise ParseError, "unexpected trailing comma in list" if input_string.empty?
    end
    raise ParseError, "No structured data has been found"
  end

  def self::parse_parameterised_token input_string
    primary_token = parse_token(input_string)
    parameters = {}
    loop do
      _discard_leading_OWS(input_string)
      break if input_string.slice(0) != ';'
      input_string.slice!(0)
      _discard_leading_OWS(input_string)
      param_name = parse_key(input_string)
      raise ParseError, "duplicate parameter #{param_name.inspect}" if parameters.key? param_name
      param_value = nil
      if input_string.slice(0) == '='
        input_string.slice!(0)
        param_value = parse_item(input_string)
      end
      parameters[param_name] = param_value
    end
    ParameterisedToken.new(primary_token, parameters)
  end

  def self::parse_item input_string
    case input_string.slice(0)
    when /[-0-9]/
      parse_number(input_string)
    when '"'
      parse_string(input_string)
    when '*'
      parse_byte_sequence(input_string)
    when '?'
      parse_boolean(input_string)
    when /[A-Za-z]/
      parse_token(input_string)
    else
      raise ParseError, "invalid item #{input_string.inspect}"
    end
  end

  def self::parse_number input_string
    type = :integer
    sign = 1
    input_number = _empty_string
    if input_string.slice(0) == '-'
      input_string.slice!(0)
      sign = -1
    end
    raise ParseError, "not a number #{input_string.inspect}" if input_string.empty?
    raise ParseError, "not a number #{input_string.inspect}" if input_string.slice(0) !~ /[0-9]/
    until input_string.empty?
      char = input_string.slice!(0)
      if char =~ /[0-9]/
        input_number << char
      elsif type == :integer && char == '.'
        input_number << char
        type = :float
      else
        input_string.replace(char + input_string)
        break
      end
      raise ParseError, "integer #{input_number} is too long" if type == :integer and input_number.length > 19
      raise ParseError, "float #{input_number} is too long" if type == :float and input_number.length > 16
    end
    if type == :integer
      output_number = input_number.to_i(10) * sign
      raise ParseError, "integer #{output_number} out of range" if output_number < -9_223_372_036_854_775_808 || output_number > 9_223_372_036_854_775_807
    else
      raise ParseError, "invalid trailing decimal point in #{input_number.inspect}" if input_number.slice(-1) == '.'
      output_number = input_number.to_f * sign
    end
    output_number
  end

  def self::parse_string input_string
    output_string = _empty_string
    raise ParseError, "not a string #{input_string.inspect}" if input_string.slice(0) != '"'
    input_string.slice!(0)
    until input_string.empty?
      char = input_string.slice!(0)
      if char == '\\'
        raise ParseError, "unterminated string" if input_string.empty?
        #else:
        next_char = input_string.slice!(0)
        raise ParseError, "invalid escape sequence" if next_char != '"' && next_char != '\\'
        output_string << next_char
      elsif char == '"'
        return output_string
      elsif char =~ /[\x00-\x1F\x7F]/
        raise ParseError, "invalid character #{char.inspect} in string"
      else
        output_string << char
      end
    end
    raise ParseError, "Reached the end of input_string without finding a closing DQUOTE"
  end

  def self::parse_token input_string
    raise ParseError, "not a token #{input_string.inspect}" if input_string.slice(0) !~ /[A-Za-z]/
    output_string = _empty_string
    until input_string.empty?
      char = input_string.slice!(0)
      if char !~ /[A-Za-z0-9_.:%*\/-]/
        input_string.replace(char + input_string)
        return output_string
      end
      output_string << char
    end
    Token.new(output_string)
  end

  def self::parse_byte_sequence input_string
    raise ParseError, "not a byte sequence #{input_string.inspect}" if input_string.slice(0) != '*'
    input_string.slice!(0)
    raise ParseError, "unterminated byte sequence" unless (_idx = input_string.index('*'))
    b64_content = input_string.slice!(0, _idx)
    input_string.slice!(0)
    raise ParseError, "invalid Base 64 characters in #{b64_content.inspect}" unless input_string =~ /\A[A-Za-z0-9+\/=]*\z/
    binary_content = _base64_decode64(b64_content)
    ByteSequence.new(binary_content)
  end

  def self::parse_boolean input_string
    raise ParseError, "not a boolean #{input_string.inspect}" if input_string.slice(0) != '?'
    input_string.slice!(0)
    if input_string.slice(0) == '1'
      input_string.slice!(0)
      return true
    end
    if input_string.slice(0) == '0'
      input_string.slice!(0)
      return false
    end
    raise ParseError, "no value has matched" # !!! not a great message
  end
end

