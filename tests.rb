
require_relative 'structured-headers'
require_relative 'libs/base32'

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
  when StructuredHeaders::BinaryContent
    Base32.strict_encode32 result.string
  else
    result
  end
end

def R(stuff) "\x1B[31m#{stuff}\x1B[0m"; end
def G(stuff) "\x1B[32m#{stuff}\x1B[0m"; end
def B(stuff) "\x1B[34m#{stuff}\x1B[0m"; end
def C(stuff) "\x1B[36m#{stuff}\x1B[0m"; end
def M(stuff) "\x1B[35m#{stuff}\x1B[0m"; end
def Y(stuff) "\x1B[93m#{stuff}\x1B[0m"; end

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
    rescue => ex
      if test['expected']
        puts ex.full_message(order: :bottom)
      end
      result = false
    end

    if result == test['expected']
      $passed += 1
    else
      $failed += 1
      puts R("FAIL: #{test['name']}")
      puts "  input:    #{test['raw'].inspect}"
      puts "  expected: #{C(test['expected'].inspect)}"
      puts "  got:      #{R(result.inspect)}"
    end
  end
end

puts '', "Done: #{M($total)} tests: #{G($passed)} passed, #{R($failed)} failed"

