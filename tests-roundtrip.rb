
require_relative 'structured-headers'
require_relative 'libs/base32'
require_relative 'libs/colours'

require 'json'

$total = 0
$passed = 0
$failed = 0

FAILURE = Object.new
def FAILURE.inspect() 'failure'; end

def __uncast__ obj, type
  case type
  when 'list'
    ary = obj.map {|item| __uncast__(item, 'item-or-innerlist') }
    SH::List.new ary
  when 'dictionary'
    hsh = obj.each_pair.map {|k, v| [__uncast__(k, 'key'), __uncast__(v, 'item-or-innerlist')] }
    Dictionary.new hsh
  when 'item', 'item-or-innerlist'
    # params
    value, params, *rest = obj
    raise "dunno why item-or-innerlist #{obj.inspect} has more than two elements" unless rest.empty?
    if value.is_a? Array
      value = __uncast__(value, 'bare-innerlist')
    else
      value = __uncast__(value, 'bare-item')
    end
    value.parameters = params
    value
  when 'bare-innerlist' # FIXME: this isn't a thing
    ary = obj.maph {|item| __uncast__(item, 'item-or-innerlist') } # FIXME: can't be an innerlist
    SH::InnerList.new ary
  when 'bare-item'
    if obj.is_a? Hash
      case obj['__type']
      when 'token'
        SH::Token.new obj['value']
      when 'binary'
        SH::ByteSequence.new Base32.decode32(obj['value'])
      else
        raise "dunno what bare-item #{obj.inspect} is"
      end
    elsif obj.is_a? String
      SH::String.new obj
    else
      SH::Item.new obj
    end
  when 'key'
    SH::Key.new obj
  else
    raise "dunno what #{type} #{obj.inspect} is"
  end
end

Dir['tests/*.json'].each do |testfile|
  json = File.read(testfile)
  tests = JSON.parse(json)
  tests.each do |test|
    next if test['must_fail'] && test['raw']

    $total += 1

    raw = test['raw']
    if raw.nil?
      header_type = test['header_type']
      header_type = 'list' if header_type == 'param-list'

      parsed = result = FAILURE
      begin
        parsed = __uncast__(test['expected'], header_type)
        result = SH::Serializer.serialize parsed
        result = [result].compact
        error  = nil
      rescue => ex
        puts ex.full_message(order: :bottom) unless test['must_fail'] || test['can_fail']
        error = ex
      end
    else
      raw = raw.join(',') if raw.is_a? Array

      header_type = test['header_type']
      header_type = 'list' if header_type == 'param-list'

      parsed = result = FAILURE
      begin
        parsed = SH::Parser.parse raw, header_type
        result = SH::Serializer.serialize parsed
        result = [result].compact
        error  = nil
      rescue => ex
        puts ex.full_message(order: :bottom)
        error = ex
      end
    end

    expect = test[test.include?('canonical') ? 'canonical' : 'raw']

    if (!error && result == expect) || (error && (test['must_fail'] || test['can_fail']))
      $passed += 1
      if ENV['VERBOSE']
        puts G("PASS: #{test['name']}")
        puts "  input:    #{test['raw'].inspect}"
        puts "  parsed:   #{N(parsed.inspect)}"
        puts "  expected: #{C(expect.inspect)}"
        puts "  got:      #{G(result.inspect)}"
      end
    else
      $failed += 1
      puts R("FAIL: #{test['name']}")
      puts "  input:    #{test['raw'].inspect}"
      puts "  parsed:   #{N(parsed.class.name + ':' + parsed.inspect)}"
      puts "  expected: #{C!(expect.inspect)}"
      puts "  got:      #{R!(result.inspect)}"
    end
  end
end

puts '', "Done: #{M($total)} tests: #{G($passed)} passed, #{R($failed)} failed"

