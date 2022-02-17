import std/streams

type
  TRangeStream = object of StreamObj
    s: Stream
    slice: Slice[int]
  RangeStream* =
    ref TRangeStream

proc rangeReadData(s: Stream, buffer: pointer, bufLen: int): int =
  let s = RangeStream(s)
  let len = min(bufLen, s.slice.len - s.getPosition - 1)
  result = s.s.readData(buffer, len)

proc rangeSetPosition (s: Stream, pos: int) =
  let s = RangeStream(s)
  s.s.setPosition pos + s.slice.a

proc rangeGetPosition (s: Stream): int =
  let s = RangeStream(s)
  s.s.getPosition() - s.slice.a

proc rangeClose (s: Stream) =
  RangeStream(s).s.close

proc rangeAtEnd (s: Stream): bool =
  let s = RangeStream(s)
  s.getPosition == s.slice.len

proc newRangeStream*(s: Stream, slice: Slice[int]): RangeStream =
  new(result)
  result.readDataImpl = rangeReadData
  result.setPositionImpl = rangeSetPosition
  result.getPositionImpl = rangeGetPosition
  result.closeImpl = rangeClose
  result.atEndImpl = rangeAtEnd
  result.s = s
  result.slice = slice
  result.setPosition 0
