
require_relative 'structured-fields'
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
  when StructuredFields::Parameters
    result.map do |(k, v)|
      if v.nil?
        [__cast__(k), nil]
      else
        [__cast__(k), __cast__(v, true)]
      end
    end
  when StructuredFields::List
    result.map {|item| __cast__(item) }
  when StructuredFields::InnerList
    result.map {|item| __cast__(item) }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when Array
    result.map {|item| __cast__(item) }
  when StructuredFields::Dictionary
    result.map {|(k, v)| [__cast__(k), __cast__(v)] }
  when Hash
    result.map {|k, v| [k, __cast__(v)] }
  when StructuredFields::Integer
    result.to_i.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::Decimal
    result.to_f.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::Boolean
    result.bool.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::String
    result.to_s.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::Token
    result.to_s.self {|v| {'__type'=>'token', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::ByteSequence
    Base32.strict_encode32(result.string).self {|v| {'__type'=>'binary', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::Date
    result.to_i.self {|v| {'__type'=>'date', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::DisplayString
    result.to_s.self {|v| {'__type'=>'displaystring', 'value'=>v} }.self {|v| ignore_parameters ? v : [v, __cast__(result.parameters)] }
  when StructuredFields::Key, Symbol
    result.to_s
#  #when Date, DateTime, Time
#  when DateTime
#    "[#{result.iso8601}]"
  else
    result
  end
end

Dir['tests/**/*.json'].each do |testfile|
  json = File.read(testfile)
  tests = JSON.parse(json)
  tests.each do |test|
    next if test['raw'].nil?

    $total += 1

    raw = test['raw']
    raw = raw.join(',') if raw.is_a? Array

    header_type = test['header_type']
    header_type = 'list' if header_type == 'param-list'

    begin
      result = StructuredFields::Parser.parse raw, header_type
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

