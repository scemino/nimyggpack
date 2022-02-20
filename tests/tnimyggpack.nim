import unittest
import std/[streams, tables, json]
import nimyggpack

test "XorStream read all":
  let s = newString([44'u8, 187, 16, 237, 151, 51, 9, 79, 216, 227, 44])
  let ss = newStringStream(s)
  let x = newXorStream(ss, s.len, xorKeys["5b6d"])
  doAssert x.readAll == "hello world"

test "GGTableDecoder read all":
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

test "bnut decode":
  let input = "hello world"
  let encoded = bnutEncode(input)
  let decoded = bnutDecode(encoded)
  doAssert decoded == input