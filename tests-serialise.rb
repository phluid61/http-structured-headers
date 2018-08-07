
require_relative 'structured-headers'

$total = 0
$passed = 0
$failed = 0

[
  [
    'dictionary',
      {'a'=>1, 'b'=>'B', 'c/d'=>3.14, 'e'=>"\n"},
      'a=1, b="B", c/d=3.14, e=*Cg==*'
  ],
  [
    'list',
      ['string', -0x10, 3.1400, "\t"],
      '"string", -16, 3.14, *CQ==*'
  ],
  [
    'param-list',
      [
        StructuredHeaders::ParameterisedIdentifier.new('text/html', {'charset'=>'utf-8'}),
        StructuredHeaders::ParameterisedIdentifier.new('text/plain', {}),
        StructuredHeaders::ParameterisedIdentifier.new('text/*', {'q'=>0.001})
      ],
      'text/html;charset="utf-8", text/plain, text/*;q=0.001'
  ],
  [ 'item',        123,   '123' ],
  [ 'item',       -123,  '-123' ],
  [ 'item',        0.5,   '0.5' ],
  [ 'item',       -0.5,  '-0.5' ],
  [ 'item',         '',    '""' ],
  [ 'item',      'a b', '"a b"' ],
  [ 'item', "\u{1234}", '*4Yi0*'],
  [ 'item', StructuredHeaders::BinaryContent.new('hello'), '*aGVsbG8=*'],
  [ 'item', StructuredHeaders::BinaryContent.new(''),      '**'],
].each do |test|
  type, object, expect = test
  $total += 1

  begin
    result = StructuredHeaders.serialise_header object, type
  rescue => ex
    if expect
      puts ex.full_message(order: :bottom)
    end
    result = nil
  end

  if result == expect
    $passed += 1
  else
    $failed += 1
    puts "FAIL: #{test['name']}"
    puts "  input:    #{test['raw'].inspect}"
    puts "  expected: #{test['expected'].inspect}"
    puts "  got:      #{result.inspect}"
  end
end

puts '', "Done: #{$total} tests: #{$passed} passed, #{$failed} failed"
