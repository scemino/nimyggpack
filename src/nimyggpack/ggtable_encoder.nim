import std/[json, streams, tables]
import ggtable_markers

type
  GGTableEncoder* = object
    s: Stream
    strings: OrderedTable[string, int32]

proc writeNull(self: var GGTableEncoder)
proc writeString(self: var GGTableEncoder, s: string)
proc writeInt(self: var GGTableEncoder, value: int)
proc writeFloat(self: var GGTableEncoder, value: float)
proc writeArray(self: var GGTableEncoder, arr: seq[JsonNode])
proc writeMap(self: var GGTableEncoder, table: OrderedTable[string, JsonNode])

proc writeValue(self: var GGTableEncoder, obj: JsonNode) =
  case obj.kind:
  of JInt:
    self.writeInt(obj.num.int)
  of JFloat:
    self.writeFloat(obj.fnum)
  of JBool:
    self.writeInt(if obj.bval: 1 else: 0)
  of JNull:
    self.writeNull()
  of JString:
    self.writeString(obj.str)
  of JArray:
    self.writeArray(obj.elems)
  of JObject:
    self.writeMap(obj.fields)

proc writeMarker(self: var GGTableEncoder, marker: byte) =
  self.s.write marker

proc writeRawString(self: var GGTableEncoder, s: string) =
  if self.strings.contains(s):
    self.s.write(self.strings[s])
  else:
    let offset = self.strings.len.int32
    self.strings[s] = offset
    self.s.write(offset)

proc writeNull(self: var GGTableEncoder) =
  self.writeMarker(Null)

proc writeString(self: var GGTableEncoder, s: string) =
  self.writeMarker(String)
  self.writeRawString(s)

proc writeInt(self: var GGTableEncoder, value: int) =
  self.writeMarker(Integer)
  self.writeRawString($value)

proc writeFloat(self: var GGTableEncoder, value: float) =
  self.writeMarker(Double)
  self.writeRawString($value)

proc writeArray(self: var GGTableEncoder, arr: seq[JsonNode]) =
  self.writeMarker(Array)
  self.s.write arr.len.int32
  for v in arr:
    self.writeValue(v)
  self.writeMarker(Array)
  
proc writeMap(self: var GGTableEncoder, table: OrderedTable[string, JsonNode]) =
  self.writeMarker(Dictionary)
  self.s.write table.len.int32
  for (key, value) in table.pairs:
    self.writeRawString(key)
    self.writeValue(value)
  self.writeMarker(Dictionary)

proc writeKey(self: var GGTableEncoder, key: string) =
  for c in key:
    self.s.write c.byte
  self.s.write 0'u8
  
proc writeKeys(self: var GGTableEncoder) =
  let plo = self.s.getPosition
  self.s.setPosition 8
  self.s.write plo.int32
  self.s.setPosition plo

  # write offsets
  var strings = newSeq[string](self.strings.len)
  for (key, value) in self.strings.pairs:
    strings[value] = key
  self.writeMarker(Offsets)
  var offset = self.s.getPosition + 4 * strings.len + 5
  for value in strings:
    self.s.write offset.int32
    offset += value.len + 1
  self.s.write EndOffsets

  # write keys
  self.writeMarker(Keys)
  for key in self.strings.keys:
    self.writeKey(key)

proc writeTable*(self: var GGTableEncoder, input: JsonNode) =
  self.s.write Signature
  self.s.write input.len.int32
  self.s.write 0'i32
  self.writeMap(input.fields)
  self.writeKeys()

proc newGGTableEncoder*(s: Stream): GGTableEncoder =
  result.s = s
