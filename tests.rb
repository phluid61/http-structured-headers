
require_relative 'structured-headers'
require_relative 'base32'

require 'json'

$total = 0
$passed = 0
$failed = 0

Dir['tests/*.json'].each do |testfile|
  json = File.read(testfile)
  tests = JSON.parse(json, symbolize_names: true)
  tests.each do |test|
    $total += 1

    raw = test[:raw]
    raw = raw.join(',') if raw.is_a? Array

    begin
      result = StructuredHeaders.parse_header raw, test[:header_type]
      result = Base32.strict_encode32 result if testfile == 'tests/binary.json'
    rescue => ex
      if test[:expected]
        puts ex.full_message(order: :bottom)
      end
      result = false
    end

    if result == test[:expected]
      $passed += 1
    else
      $failed += 1
      puts "FAIL: #{test[:raw].inspect} expected #{test[:expected].inspect}, got #{result.inspect}"
    end
  end
end

puts "Done: #{$total} tests: #{$passed} passed, #{$failed} failed"
