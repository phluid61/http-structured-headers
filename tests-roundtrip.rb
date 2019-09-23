
require_relative 'structured-headers'
require_relative 'libs/base32'
require_relative 'libs/colours'

require 'json'

$total = 0
$passed = 0
$failed = 0

FAILURE = Object.new
def FAILURE.inspect() 'failure'; end

def __cast__ result
  case result
  when Array
    result.map {|item| __cast__ item }
  when Hash
    result.map {|k, v| [k, __cast__(v)] }.to_h
  when StructuredHeaders::Token, Symbol
    result.to_s
  when StructuredHeaders::ByteSequence
    Base32.strict_encode32 result.string
  else
    result
  end
end

Dir['tests/*.json'].each do |testfile|
  json = File.read(testfile)
  tests = JSON.parse(json)
  tests.each do |test|
    next if test['must_fail']

    $total += 1

    raw = test['raw']
    raw = raw.join(',') if raw.is_a? Array

    header_type = test['header_type']
    header_type = 'list' if header_type == 'param-list'

    parsed = result = FAILURE
    begin
      parsed = SH::Parser.parse raw, header_type
      result = SH::Serializer.serialize parsed
      result = [result]
      error  = nil
    rescue => ex
      puts ex.full_message(order: :bottom)
      error = ex
    end

    expect = test[test.include?('canonical') ? 'canonical' : 'raw']

    if !error && result == expect
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

