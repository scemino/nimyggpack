import std/[streams, tables, json]
import ggpack_entry
import xor_stream
import ggtable_encoder

type
  GGPackBuilder* = object
    s: Stream
    entries: OrderedTable[string, GGPackEntry]
    key: XorKey

proc newGGPackBuilder*(s: Stream, key: XorKey): GGPackBuilder =
  result.s = s
  result.key = key
  result.s.write 0'i32
  result.s.write 0'i32

proc addBytes*(self: var GGPackBuilder, name, buffer: string) =
  let bytes = xorEncode(buffer, self.key)
  var entry = GGPackEntry(offset: self.s.getPosition, size: bytes.len)
  self.s.write bytes
  self.entries[name] = entry

proc addTable*(self: var GGPackBuilder, name: string, table: JsonNode) =
  self.addBytes(name, ggtableEncode(table))

proc toJson(filename: string, entry: GGPackEntry): JsonNode =
  result = newJObject()
  result.add("filename", newJString(filename))
  result.add("offset", newJInt(entry.offset))
  result.add("size", newJInt(entry.size))

proc close*(self: var GGPackBuilder) =
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
  # self.s.close
