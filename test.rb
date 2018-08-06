require_relative 'base32/rfc4648'
require_relative 'base32/z-base-32'
require_relative 'base32/crockford-base32'

module Display
end

class <<Display
  NORMAL = "\e[0m"
  H1  = "\e[30;107m"
  H2  = "\e[36m"
  OK  = "\e[32m"
  ERR = "\e[31m"

  def h1 *stuff
    puts "== #{H1}#{stuff.join}#{NORMAL}"
  end

  def h2 *stuff
    puts "-- #{H2}#{stuff.join}#{NORMAL}"
  end

  def label key, result, exp=nil
    if exp
      str = result == exp ? _ok(result.inspect) : _err(result.inspect)
    else
      str = result.inspect
    end
    puts('%-15s: %s' % [key, str])
  end

  def _err *stuff
    "#{ERR}#{stuff.join}#{NORMAL}"
  end

  def _ok *stuff
    "#{OK}#{stuff.join}#{NORMAL}"
  end
end

$binary_data = [
  -'',
  -'x',
  -'xy',
  -'xyz',
  -'xyza',
  -'UUUUU',
  -'hello world! how are you?',
  -'q098y q098 098 y78213 ssf2',
  [0x00, 0x10, 0x30, 0x80, 0xFE, 0xFF].pack('C*'),
]

[
  Base32,
  ZBase32,
  CrockfordBase32,
  [CrockfordBase32, true],
].each do |mod|
  if mod.is_a? Array
    mod, *rest = *mod
  else
    rest = []
  end

  Display.h1 " #{mod} #{rest.empty? ? '' : '('+rest.join(',')+') '}"

  $binary_data.each do |bin|
    Display.h2 bin.inspect

    s32 = mod.strict_encode32(bin, *rest)
    Display.label '  strict_encode', s32
    Display.label '=>strict_decode', (mod.strict_decode32(s32, *rest) rescue $!), bin
    Display.label '=>decode', (mod.decode32(s32, *rest) rescue $!), bin

    if (p = mod.singleton_class::PADDING) && s32.end_with?(p)
      t32 = s32.sub(/(#{p})+\z/, '')
      Display.label '+ strip', t32
      Display.label '=>decode', (mod.decode32(t32, *rest) rescue $!), bin
    end

    b32 = mod.encode32(bin, *rest)
    Display.label '  encode', b32
    Display.label '=>decode', (mod.decode32(b32, *rest) rescue $!), bin

    puts ''
  end
end

