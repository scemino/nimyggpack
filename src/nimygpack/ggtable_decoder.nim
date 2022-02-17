import std/[streams, tables, strformat, json, strutils, sequtils]
import range_stream
import xor_stream

type
  GGTableDecoder = object
    s: Stream
    offsets: seq[int]
    hash*: JsonNode
  GGPackDecoder = object
    key: XorKey
    s: Stream
    entries*: Table[string, GGPackEntry]
  GGPackEntry = object
    offset, size: int

const Signature = 0x04030201
const Null = 1
const Dictionary = 2
const Array = 3
const String = 4
const Integer = 5
const Double = 6
const Offsets = 7
const Keys = 8
const EndOffsets = 0xFFFFFFFF

proc readPlo(s: Stream): seq[int] =
  let ploIndex = s.readUint32().int
  let pos = s.getPosition
  s.setPosition(ploIndex)
  let c = s.readUint8()
  if c != Offsets:
    raise newException(Exception, "GGPack cannot find plo :(")
  var offset = 0
  while offset != EndOffsets:
    offset = s.readUint32().int
    if offset != EndOffsets:
      result.add(offset)
  s.setPosition(pos)

proc readHash(self: GGTableDecoder): JsonNode
proc readValue(self: GGTableDecoder): JsonNode

proc readString(self: GGTableDecoder, index: int): string =
  let pos = self.s.getPosition
  self.s.setPosition(self.offsets[index])
  while true:
    var c = self.s.readUint8()
    if c == 0:
      self.s.setPosition(pos)
      return result
    result.add(c.char)

proc readArray(self: GGTableDecoder): JsonNode =
  var c = self.s.readUint8()
  if c != Array:
    raise newException(Exception, "trying to parse a non-array")
  result = newJArray()
  let length = self.s.readUint32()
  for i in 0..<length:
    let item = self.readValue()
    result.add(item)
  c = self.s.readUint8()
  if c != Array:
    raise newException(Exception, "unterminated array")

proc readValue(self: GGTableDecoder): JsonNode =
  let ggType = self.s.peekUint8()
  case ggType:
  of Null:
    discard self.s.readUint8
    result = newJNull()
  of Dictionary:
    result = self.readHash()
  of Array:
    result = self.readArray()
  of String:
    discard self.s.readUint8
    let ploIdx = self.s.readUint32().int
    result = newJString(self.readString(ploIdx))
  of Integer, Double:
    discard self.s.readUint8
    let ploIdx = self.s.readUint32().int
    let num_str = self.readString(ploIdx)
    result = if ggType == Integer: newJInt(parseInt(num_str)) else: newJFloat(
        parseFloat(num_str))
  else:
    raise newException(Exception, fmt"Not Implemented: value type {ggType}")

proc readHash(self: GGTableDecoder): JsonNode =
  result = newJObject()
  var c = self.s.readUint8
  if c != Dictionary:
    raise newException(Exception, "trying to parse a non-hash")
  let nPairs = self.s.readUint32()
  for i in 0..<nPairs:
    let key = self.readString(self.s.readUint32().int)
    let value = self.readValue()
    result[key] = value
  c = self.s.readUint8
  if c != Dictionary:
    raise newException(Exception, "unterminated hash")

proc newString*(bytes: openArray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

proc extract*(self: GGPackDecoder, entry: string): Stream =
  let e = self.entries[entry]
  echo e
  let size = e.offset + e.size
  let bytes = newRangeStream(self.s, (e.offset..size))
  newXorStream(bytes, e.size, self.key)

proc newGGTableDecoder*(s: Stream): GGTableDecoder =
  let str = s.readAll
  var s = newStringStream(str)
  let signature = s.readUint32
  if signature != Signature:
    raise newException(Exception, fmt"This is NOT a valid ggpack file :( {signature:X}")
  discard s.readUint32.int # num entries
  result.offsets = readPlo(s)
  result.s = s

  # read entries as hash
  result.hash = result.readHash()

proc newGGPackDecoder*(s: Stream, key: XorKey): GGPackDecoder =
  let entriesOffset = s.readUint32.int
  let entriesSize = s.readUint32.int
  s.setPosition entriesOffset

  # decode entries
  var entriesData = newSeq[byte](entriesSize)
  discard s.readData(entriesData[0].addr, entriesSize)
  var str = newString(entriesData)
  var ss = newStringStream(str)
  var byteStream = newXorStream(ss, entriesSize, key)

  # read entries as hash
  let ggmap = newGGTableDecoder(byteStream)
  result.s = s
  result.key = key
  result.entries = ggmap.hash["files"].elems.mapIt((it["filename"].str,
      GGPackEntry(offset: it["offset"].num.int, size: it[
      "size"].num.int))).toTable

proc extractTable*(self: GGPackDecoder, entry: string): JsonNode =
  newGGTableDecoder(self.extract(entry)).hash
