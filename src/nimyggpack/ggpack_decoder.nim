import std/[streams, tables, json, sequtils]
import range_stream
import xor_stream
import ggtable_decoder

type
  GGPackDecoder* = object
    key: XorKey
    s: Stream
    entries*: Table[string, GGPackEntry]
  GGPackEntry = object
    offset, size: int

proc newString*(bytes: openArray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

proc extract*(self: GGPackDecoder, entry: string): Stream =
  let e = self.entries[entry]
  let size = e.offset + e.size
  let bytes = newRangeStream(self.s, (e.offset..size))
  newXorStream(bytes, e.size, self.key)

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
