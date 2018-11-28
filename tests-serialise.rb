
require_relative 'structured-headers'
require_relative 'libs/colours'

$total = 0
$passed = 0
$failed = 0

[
  [
    'dictionary',
      {'a'=>1, :b=>'B', 'c-d'=>3.14, 'e_f'=>"\n"},
      'a=1, b="B", c-d=3.14, e_f=*Cg==*'
  ],
  [
    'list',
      ['string', -0x10, 3.1400, "\t", :foobar, ],
      '"string", -16, 3.14, *CQ==*, foobar'
  ],
  [
    'param-list',
      [
        StructuredHeaders::ParameterisedIdentifier.new('text/html', {'charset'=>:'utf-8'}),
        StructuredHeaders::ParameterisedIdentifier.new('text/plain'),
        StructuredHeaders::ParameterisedIdentifier.new('text/*', q: 0.001)
      ],
      'text/html;charset=utf-8, text/plain, text/*;q=0.001'
  ],
  [
    'list-list',
      [[:a, :b],['c'],[-4, 5.6, "\n"]],
      'a; b, "c", -4; 5.6; *Cg==*'
  ],
  [ 'list-list',    [],       '' ],
  [ 'list-list',    [[],[]],     ],
  [ 'item',        123,    '123' ],
  [ 'item',      -0b10,     '-2' ],
  [ 'item',       1/2r,    '0.5' ],
  [ 'item',      -0.50,   '-0.5' ],
  [ 'item',         '',     '""' ],
  [ 'item',      'a b',  '"a b"' ],
  [ 'item',      'a"b', '"a\\"b"'],
  [ 'item', "\u{1234}",  '*4Yi0*'],
  [ 'item', StructuredHeaders::ByteSequence.new('hello'), '*aGVsbG8=*'],
  [ 'item', StructuredHeaders::ByteSequence.new(''),      '**'],
  [ 'item',    :foobar,  'foobar'],
  [ 'item',    :FooBar,  'FooBar'],
  [ 'item', StructuredHeaders::Identifier.new('a_b-c3/*'), 'a_b-c3/*'],
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
    if ENV['VERBOSE']
      puts G("PASS:")
      puts "  input:    #{object.inspect}"
      puts "  expected: #{expect ? C(expect.inspect) : Y('failure')}"
      puts "  got:      #{result ? G(result.inspect) : Y('failure')}"
    end
  else
    $failed += 1
    puts R("FAIL:")
    puts "  input:    #{object.inspect}"
    puts "  expected: #{expect ? C(expect.inspect) : Y('failure')}"
    puts "  got:      #{result ? R(result.inspect) : R('failure')}"
  end
end

puts '', "Done: #{M($total)} tests: #{G($passed)} passed, #{R($failed)} failed"
