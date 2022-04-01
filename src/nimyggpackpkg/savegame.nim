import std/times
import std/json
import std/algorithm
import std/sets
import ggtable_decoder

const DELTA = 0x9e3779b9'u32

type Savegame* = object
  data*: JsonNode
  time*: Time

var savegameKey = [0xAEA4EDF3'u32, 0xAFF8332A'u32, 0xB5A2DBB4'u32, 0x9B4BA022'u32]

proc mx(sum, y, z: uint32, p, e: uint, k: openArray[uint32]): uint32 =
    result = (z shr 5 xor y shl 2) + (y shr 3 xor z shl 4) xor (sum.uint32 xor y) + (k[p and 3 xor e] xor z)

proc decrypt(v: var openArray[uint32], key: openArray[uint32]) =
  var sum, y, z, rounds: uint32
  var p, e: uint
  let n = v.len
  rounds = (6 + 52 div n).uint32
  sum = (rounds * DELTA)
  y = v[0]
  for i in 0..<rounds:
    e = (sum shr 2) and 3
    for p in countdown((n - 1).uint, 1):
      z = v[p - 1]
      v[p] -= mx(sum, y, z, p, e, key)
      y = v[p]
    z = v[n - 1]
    v[0] -= mx(sum, y, z, p, e, key)
    y = v[0]
    sum -= DELTA

proc computeHash(data: openArray[byte]): int32 =
  result = 0x6583463'i32
  for i in 0..<data.len:
    result += data[i].int32

template toOpenArr[Tin, Tout](arr: openArray[Tin], first, size: int, t: Tout): openArray[Tout] =
  var p = cast[ptr UncheckedArray[Tout]](arr[0].addr)
  p.toOpenArray(first, (first + size) * sizeof(Tin) div sizeof(Tout) - 1)

template toOpenArr[Tin, Tout](arr: openArray[Tin], t: Tout): openArray[Tout] =
  var p = cast[ptr UncheckedArray[Tout]](arr[0].addr)
  p.toOpenArray(0, arr.len * sizeof(Tin) div sizeof(Tout) - 1)

proc loadSaveGame*(path: string): Savegame =
  var f = open(path, fmRead)
  var data = f.readAll()
  decrypt(data.toOpenArr(0'u32), savegameKey)

  let hashData = cast[ptr int32](data[data.len-16].addr)[]
  let t = fromUnix(cast[ptr int32](data[data.len-12].addr)[])
  
  let hashCheck = computeHash(data.toOpenArr(0, data.len-16, 0'u8))
  if hashData == hashCheck:
    result = Savegame(data: ggtableDecode(data), time: t)
