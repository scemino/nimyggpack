import std/[streams, tables, json]
import ggpack_entry
import xor_stream
import ggtable_encoder

type
  GGPackWriter* = object
    s: Stream
    entries: OrderedTable[string, GGPackEntry]
    key: XorKey
    closeStream: bool

proc newGGPackWriter*(s: Stream, key: XorKey;
    closeStream = true): GGPackWriter =
  result.s = s
  result.key = key
  result.s.write 0'i32
  result.s.write 0'i32
  result.closeStream = closeStream

proc write*(self: var GGPackWriter, name, buffer: string) =
  let bytes = xorEncode(buffer, self.key)
  var entry = GGPackEntry(offset: self.s.getPosition, size: bytes.len)
  self.s.write bytes
  self.entries[name] = entry

proc write*(self: var GGPackWriter, name: string, table: JsonNode) =
  self.write(name, ggtableEncode(table))

proc toJson(filename: string, entry: GGPackEntry): JsonNode =
  result = newJObject()
  result.add("filename", newJString(filename))
  result.add("offset", newJInt(entry.offset))
  result.add("size", newJInt(entry.size))

proc close*(self: var GGPackWriter) =
  let entriesOffset = self.s.getPosition
  var jPack = newJObject()
  var jFiles = newJArray()
  for (k, v) in self.entries.pairs:
    jFiles.add(toJson(k, v))
  jPack["files"] = jFiles
  let entriesBytes = xorEncode(ggtableEncode(jPack), self.key)
  self.s.write entriesBytes
  self.s.setPosition 0
  self.s.write entriesOffset.int32
  self.s.write entriesBytes.len.int32
  if self.closeStream:
    self.s.close
