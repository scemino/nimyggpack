import std/[streams, tables]

type
  XorKey* = object
    ## Creates a ‘XorKey‘ with a given ‘magicBytes‘ and ‘multiplier‘.
    magicBytes: seq[int]
    multiplier: int
  TXorStream = object of StreamObj
    s: Stream
    previous: int
    pos: int
    key: XorKey
  XorStream* =
    ref TXorStream

const xorKeys* = {
  "56ad": XorKey(magicBytes: @[0x4F, 0xD0, 0xA0, 0xAC, 0x4A, 0x56, 0xB9, 0xE5,
      0x93, 0x79, 0x45, 0xA5, 0xC1, 0xCB, 0x31, 0x93], multiplier: 0xAD), # 56ad
  "566d": XorKey(magicBytes: @[0x4F, 0xD0, 0xA0, 0xAC, 0x4A, 0x56, 0xB9, 0xE5,
      0x93, 0x79, 0x45, 0xA5, 0xC1, 0xCB, 0x31, 0x93], multiplier: 0x6D), # 566d
  "5b6d": XorKey(magicBytes: @[0x4F, 0xD0, 0xA0, 0xAC, 0x4A, 0x5B, 0xB9, 0xE5,
      0x93, 0x79, 0x45, 0xA5, 0xC1, 0xCB, 0x31, 0x93], multiplier: 0x6D), # 5b6d
  "5bad": XorKey(magicBytes: @[0x4F, 0xD0, 0xA0, 0xAC, 0x4A, 0x5B, 0xB9, 0xE5,
      0x93, 0x79, 0x45, 0xA5, 0xC1, 0xCB, 0x31, 0x93], multiplier: 0xAD), # 5bad
  "delores": XorKey(magicBytes: @[0x3F, 0x41, 0x41, 0x60, 0x95, 0x87, 0x4A,
      0xE6, 0x34, 0xC6, 0x3A, 0x86, 0x29, 0x27, 0x77, 0x8D, 0x38, 0xB4, 0x96,
      0xC9, 0x38, 0xB4, 0x96, 0xC9, 0x00, 0xE0, 0x0A, 0xC6, 0x00, 0xE0, 0x0A,
      0xC6, 0x00, 0x3C, 0x1C, 0xC6, 0x00, 0x3C, 0x1C, 0xC6, 0x00, 0xE4, 0x40,
      0xC6, 0x00, 0xE4, 0x40, 0xC6], multiplier: 0x6D),           # delores
}.toTable

proc xorDecodeData(s: Stream, buffer: pointer, bufLen: int): int =
  var s = XorStream(s)
  result = s.s.readData(buffer, bufLen)
  var buf = cast[ptr UncheckedArray[byte]](buffer)
  for i in 0..<bufLen:
    let x = buf[i].int xor s.key.magicBytes[s.pos and 0x0F] xor (i *
        s.key.multiplier)
    buf[i] = (x xor s.previous).byte
    s.previous = x
    inc s.pos

proc xorEncodeData(s: Stream, buffer: pointer, bufLen: int): int =
  var s = XorStream(s)
  result = s.s.readData(buffer, bufLen)
  var buf = cast[ptr UncheckedArray[byte]](buffer)
  for i in 0..<bufLen:
    var x = buf[i].int xor s.previous
    buf[i] = (x xor s.key.magicBytes[i and 0x0F] xor (i *
        s.key.multiplier)).byte
    s.previous = x

proc xorSetPosition (s: Stream, pos: int) =
  var s = XorStream(s)
  s.s.setPosition pos

proc xorGetPosition (s: Stream): int =
  var s = XorStream(s)
  s.s.getPosition

proc xorClose (s: Stream) =
  XorStream(s).s.close

proc xorAtEnd (s: Stream): bool =
  XorStream(s).s.atEnd

proc newXorDecodeStream*(s: Stream, len: int, key: XorKey): XorStream =
  new(result)
  result.s = s
  result.previous = (len and 0xFF)
  result.readDataImpl = xorDecodeData
  result.setPositionImpl = xorSetPosition
  result.getPositionImpl = xorGetPosition
  result.atEndImpl = xorAtEnd
  result.closeImpl = xorClose
  result.key = key

proc newXorEncodeStream*(s: Stream, len: int, key: XorKey): XorStream =
  new(result)
  result.s = s
  result.previous = (len and 0xFF)
  result.readDataImpl = xorEncodeData
  result.setPositionImpl = xorSetPosition
  result.getPositionImpl = xorGetPosition
  result.atEndImpl = xorAtEnd
  result.closeImpl = xorClose
  result.key = key

proc xorEncode*(s: string, key: XorKey): string =
  var xorStream = newXorEncodeStream(newStringStream(s), s.len, key)
  xorStream.readAll

proc xorDecode*(s: string, key: XorKey): string =
  var xorStream = newXorDecodeStream(newStringStream(s), s.len, key)
  xorStream.readAll
