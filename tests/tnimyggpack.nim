import unittest
import std/[streams, tables, json]
import nimyggpack

test "Xor encode":
  let expected = newString([44'u8, 187, 16, 237, 151, 51, 9, 79, 216, 227, 44])
  let actual = xorEncode("hello world", xorKeys["5b6d"])
  doAssert actual == expected

test "Xor decode":
  let s = newString([44'u8, 187, 16, 237, 151, 51, 9, 79, 216, 227, 44])
  let actual = xorDecode(s, xorKeys["5b6d"])
  doAssert actual == "hello world"

test "Table decode":
  let f = newFileStream("tests/data/mapEncoded")
  let actual = pretty(newGGTableDecoder(f).hash)
  let expected = """
{
  "integer": 5,
  "array": [
    null,
    0,
    1,
    3.14,
    "string",
    {
      "key": "value"
    }
  ]
}"""
  f.close
  doAssert actual == expected

test "Table encode":
  let data = """
{
  "integer": 5,
  "array": [
    null,
    0,
    1,
    3.14,
    "string",
    {
      "key": "value"
    }
  ]
}"""
  let j = parseJson(data)
  var ss = newStringStream()
  var encoder = newGGTableEncoder(ss)
  encoder.writeTable j
  ss.setPosition(0)
  let actual = ss.readAll
  let expected = open("tests/data/mapEncoded").readAll
  doAssert actual == expected
  doAssert ggtableEncode(j) == expected

test "bnut decode":
  let input = "hello world"
  let encoded = bnutEncode(input)
  let decoded = bnutDecode(encoded)
  doAssert decoded == input

test "ggpack decode":
  var s = newStringStream()
  var builder = newGGPackBuilder(s, xorKeys["5b6d"])
  builder.addBytes("foo.txt", "hello")
  builder.addBytes("bar.txt", "world")
  builder.close

  s.setPosition 0
  let decoder = newGGPackDecoder(s, xorKeys["5b6d"])
  doAssert decoder.extract("foo.txt").readAll == "hello"
  doAssert decoder.extract("bar.txt").readAll == "world"
