
require_relative 'structured-headers'
require_relative 'libs/base32'
require_relative 'libs/colours'

require 'json'

$total = 0
$passed = 0
$failed = 0

def __cast__ result
  case result
  when Array
    result.map {|item| __cast__ item }
  when Hash
    result.map {|k, v| [k, __cast__(v)] }.to_h
  when StructuredHeaders::ParameterisedIdentifier
    [result.identifier, __cast__(result.parameters)]
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
    $total += 1

    raw = test['raw']
    raw = raw.join(',') if raw.is_a? Array

    begin
      result = StructuredHeaders.parse_header raw, test['header_type']
      result = __cast__ result
      error  = nil
    rescue => ex
      if test['expected'] && !test['can_fail']
        puts ex.full_message(order: :bottom)
      end
      result = false
      error = ex
    end

    if result == test['expected'] || (error && test['can_fail'])
      $passed += 1
      if ENV['VERBOSE']
        puts G("PASS: #{test['name']}")
        puts "  input:    #{test['raw'].inspect}"
        puts "  expected: #{C(test['expected'].inspect)}#{test['can_fail'] ? ' or failure' : ''}"
        puts "  got:      #{G(result.inspect)}"
      end
    else
      $failed += 1
      puts R("FAIL: #{test['name']}")
      puts "  input:    #{test['raw'].inspect}"
      puts "  expected: #{C(test['expected'].inspect)}#{test['can_fail'] ? ' or failure' : ''}"
      puts "  got:      #{R(result.inspect)}"
    end
  end
end

puts '', "Done: #{M($total)} tests: #{G($passed)} passed, #{R($failed)} failed"

