
require 'base64'
require 'date'

module StructuredHeaders

  class SerialisationError < RuntimeError
  end

  class ParseError < RuntimeError
  end

  class ParameterisedIdentifier
    def initialize identifier, parameters={}
      @identifier = identifier
      @parameters = parameters
    end
    attr_reader :identifier, :parameters

    def each_parameter
      return enum_for(:each_parameter) unless block_given?
      @parameters.each { |parameter| yield parameter }
      self
    end

    def []= key, value
      @parameters[key] = value
    end

    def to_s
      "\#<#{self.class.name}:#{@identifier.inspect}#{@parameters.map{|k,v|";#{k.inspect}=#{v.inspect}"}.join}>"
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

  class Identifier
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
  SERIALISE_IDENTIFIER = /\A[a-z][a-z0-9_*\/-]*\z/

  def self::serialise_header obj, type
    case type
    when 'dictionary'
      serialise_dictionary(obj)
    when 'list'
      serialise_list(obj)
    when 'param-list'
      serialise_parameterised_list(obj)
    when 'item'
      serialise_item(obj)
    else
      raise "unable to serialise #{type.inspect}"
    end
  end

  def self::serialise_dictionary hsh
    output = _empty_string
    hsh.each_with_index do |member, idx|
      member_name, member_value = member

      name = serialise_identifier(member_name)
      output << name
      output << '='
      value = serialise_item(member_value)
      output << value
      if idx < (hsh.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::serialise_list ary
    output = _empty_string
    ary.each_with_index do |mem, idx|
      value = serialise_item(mem)
      output << value
      if idx < (ary.length - 1)
        output << ','
        output << ' '
      end
    end
    output
  end

  def self::serialise_parameterised_list ary
    output = _empty_string
    ary.each_with_index do |member, idx|
      id = serialise_identifier(member.identifier)
      output << id
      member.each_parameter do |parameter|
        param_name, param_value = parameter

        output << ';'
        name = serialise_identifier(param_name)
        output << name
        if param_value
          value = serialise_item(param_value)
          output << '='
          output << value
        end
      end
      if idx < (ary.length - 1)
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
    when Symbol, Identifier
      :identifier
    when Date, DateTime, Time
      :date
    else
      raise SerialisationError, "not a valid 'item' type: #{item.class.name}"
    end
  end

  def self::serialise_item input
    _type = _typeof(input) # includes potential failure
    case _type
    when :integer
      serialise_integer(input)
    when :float
      serialise_float(input)
    when :string
      serialise_string(input)
    when :identifier
      serialise_identifier(input)
    when :boolean
      serialise_boolean(input)
     when :date
       serialise_date(input)
    else
      serialise_byte_sequence(input)
    end
  end

  def self::serialise_integer input
    input = input.to_i
    raise SerialisationError, "integer #{input.inspect} out of bounds" if input < -9_223_372_036_854_775_808 || input > 9_223_372_036_854_775_807
    output = _empty_string
    output << '-' if input < 0
    output << input.abs.to_s(10)
    output
  end

  def self::serialise_float input
    input = input.to_f
    output = _empty_string
    output << '-' if input < 0
    output << input.abs.to_s # !!! uh... close enough
    output
  end

  def self::serialise_string input
    input = input.to_s
    raise SerialisationError, "string contains invalid characters #{input.inspect}" if input !~ SERIALISE_STRING
    output = _empty_string
    output << '"'
    input.each_char do |char|
      output << '\\' if char == '\\' || char == '"'
      output << char
    end
    output << '"'
    output
  end

  def self::serialise_identifier input
    input = input.to_s
    raise SerialisationError, "identifier contains invalid characters #{input.inspect}" if input !~ SERIALISE_IDENTIFIER
    output = _empty_string
    output << input
    output
  end

  def self::serialise_byte_sequence input
    input = input.to_s.b
    output = _empty_string
    output << '*'
    output << Base64.strict_encode64(input)
    output << '*'
    output
  end

  def self::serialise_boolean input
    #raise SerialisationError if input is not boolean
    output = _empty_string
    output << '!'
    output << 'T' if input
    output << 'F' if !input
    output
  end

  # XXX
  def self::serialise_date input
    input = input.to_datetime
    input.httpdate
  end

  # --------------------------------------------------

  LEADING_OWS = /\A[\x20\x09]+/

  def self::_discard_leading_OWS input_string
    input_string.sub!(LEADING_OWS, '')
  end

  def self::parse_header input_string, header_type
    if input_string.respond_to?(:map) && !input_string.respond_to?(:to_str)
      input_string = input_string.map{|s| s.to_s }.join(',')
    end
    input_string = +"#{input_string}"
    _discard_leading_OWS input_string
    case header_type.to_s
    when 'dictionary'
      output = parse_dictionary(input_string)
    when 'list'
      output = parse_list(input_string)
    when 'param-list'
      output = parse_parameterised_list(input_string)
    else
      output = parse_item(input_string)
    end
    _discard_leading_OWS input_string
    raise ParseError, "input_string should be empty #{input_string.inspect}" unless input_string.empty?
    output
  end

  def self::parse_dictionary input_string
    dictionary = {}
    until input_string.empty?
      this_key = parse_identifier(input_string)
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

  def self::parse_parameterised_list input_string
    items = []
    until input_string.empty?
      item = parse_parameterised_identifier(input_string)
      items << item
      _discard_leading_OWS(input_string)
      return items if input_string.empty?
      raise ParseError, "list missing comma after #{item.inspect}" if input_string.slice!(0) != ','
      _discard_leading_OWS(input_string)
      raise ParseError, "unexpected trailing comma in list" if input_string.empty?
    end
    raise ParseError, "No structured data has been found"
  end

  def self::parse_parameterised_identifier input_string
    primary_identifier = parse_identifier(input_string)
    parameters = {}
    loop do
      break if input_string.slice(0) != ';'
      input_string.slice!(0)
      _discard_leading_OWS(input_string)
      param_name = parse_identifier(input_string)
      raise ParseError, "duplicate parameter #{param_name.inspect}" if parameters.key? param_name
      param_value = nil
      if input_string.slice(0) == '='
        input_string.slice!(0)
        param_value = parse_item(input_string)
      end
      parameters[param_name] = param_value
    end
    ParameterisedIdentifier.new(primary_identifier, parameters)
  end

  def self::parse_item input_string
    _discard_leading_OWS(input_string)
    case input_string.slice(0)
    when /[-0-9]/
      parse_number(input_string)
    when '"'
      parse_string(input_string)
    when '*'
      parse_byte_sequence(input_string)
    when '!'
      parse_boolean(input_string)
    when /[a-z]/
      parse_identifier(input_string)
    when /[SMTWF]/
      parse_date(input_string)
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
    raise ParseError, "unterminated string"
  end

  def self::parse_identifier input_string
    raise ParseError, "not an identifier #{input_string.inspect}" if input_string.slice(0) !~ /[a-z]/
    output_string = _empty_string
    until input_string.empty?
      char = input_string.slice!(0)
      if char !~ /[a-z0-9_*\/-]/
        input_string.replace(char + input_string)
        return output_string
      end
      output_string << char
    end
    output_string
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
    raise ParseError, "not a boolean #{input_string.inspect}" if input_string.slice(0) != '!'
    input_string.slice!(0)
    if input_string.slice(0).upcase == 'T'
      input_string.slice!(0)
      return true
    end
    if input_string.slice(0).upcase == 'F'
      input_string.slice!(0)
      return false
    end
    raise ParseError, "no value has matched" # !!! not a great message
  end

  # XXX
  def self::parse_date input_string
    case input_string
    when /\A(Sun|Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d\d) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d\d\d\d) (\d\d):(\d\d):(\d\d) GMT\z/
      Date.httpdate(input_string)
    when /\A(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), (\d\d)-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d\d) (\d\d):(\d\d):(\d\d) GMT\z/
      # FIXME:
      #   Recipients of a timestamp value in rfc850-date format, which uses a
      #   two-digit year, MUST interpret a timestamp that appears to be more
      #   than 50 years in the future as representing the most recent year in
      #   the past that had the same last two digits.
      Date.strptime("#$2 #$3 #$4 #$5:#$6:#$7 +0000", '%d %b %d %H:%I:%S %z')
    when /\A(Sun|Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ((?: |\d)\d) (\d\d):(\d\d):(\d\d) (\d\d\d\d)\z/
      Date.strptime("#$2 #$3 #$4:#$5:#$6 #$7", '%b %e %H:%I:%S')
    else
      raise ParseError, "unable to recognise date format #{input_string.inspect}"
    end
  end
end

