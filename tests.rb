
require_relative 'structured-headers'
require_relative 'libs/base32'
require_relative 'libs/colours'

require 'mug/self'
require 'json'
#require 'date'

$total = 0
$passed = 0
$failed = 0

FAILURE = Object.new
def FAILURE.inspect() 'failure'; end

def __cast__ result, ignore_parameters=false
  case result
  when SH::Parameters
    result.map do |(k, v)|
      if v.nil?
        [__cast__(k), nil]
      else
        [__cast__(k), __cast__(v, true)]
      end
    end.to_h
  when SH::List
    result.map {|item| __cast__(item) }
  when SH::InnerList
    result.map {|item| __cast__(item) }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when Array
    result.map {|item| __cast__(item) }
  when SH::Dictionary
    result.map {|(k, v)| [__cast__(k), __cast__(v)] }.to_h
  when Hash
    result.map {|k, v| [k, __cast__(v)] }.to_h
  when SH::Integer
    result.to_i.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::Decimal
    result.to_f.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::Boolean
    result.bool.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::String
    result.to_s.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::Token
    result.to_s.self {|v| {'__type'=>'token', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::ByteSequence
    Base32.strict_encode32(result.string).self {|v| {'__type'=>'binary', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when SH::Key, Symbol
    result.to_s
#  #when Date, DateTime, Time
#  when DateTime
#    "[#{result.iso8601}]"
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

    header_type = test['header_type']
    header_type = 'list' if header_type == 'param-list'

    begin
      result = SH::Parser.parse raw, header_type
      result = __cast__ result
      error  = nil
    rescue => ex
      puts ex.full_message(order: :bottom) unless test['must_fail'] || test['can_fail']
      result = FAILURE
      error = ex
    end

    if (!error && result == test['expected']) || (error && (test['must_fail'] || test['can_fail']))
      $passed += 1
      if ENV['VERBOSE']
        puts G("PASS: #{test['name']}")
        puts "  input:    #{test['raw'].inspect}"
        if test['must_fail']
          puts "  expected: failure"
        else
          puts "  expected: #{C(test['expected'].inspect)}#{test['can_fail'] ? ' or failure' : ''}"
          puts "  got:      #{G(result.inspect)}"
        end
      end
    else
      $failed += 1
      puts R("FAIL: #{test['name']}")
      puts "  input:    #{test['raw'].inspect}"
      if test['must_fail']
        puts "  expected: #{N!('failure')}"
      else
        puts "  expected: #{C!(test['expected'].inspect)}#{test['can_fail'] ? ' or failure' : ''}"
      end
      puts "  got:      #{R!(result.inspect)}"
    end
  end
end

puts '', "Done: #{M($total)} tests: #{G($passed)} passed, #{R($failed)} failed"

