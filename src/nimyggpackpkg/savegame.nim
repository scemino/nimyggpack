import std/times
import std/json
import std/algorithm
import std/sets
import ggtable_decoder
import ggtable_encoder

proc memset*(p: pointer, value: cint, size: csize_t) {.importc, header: "<string.h>".}

const DELTA = 0x9e3779b9'u32

type
  Savegame* = object
    data*: JsonNode
    time*: Time
  HashError* = object of CatchableError

const savegameKey = [0xAEA4EDF3'u32, 0xAFF8332A'u32, 0xB5A2DBB4'u32, 0x9B4BA022'u32]

proc mx(sum, y, z: uint32, p, e: uint, k: openArray[uint32]): uint32 =
    result = ((z shr 5 xor y shl 2) + (y shr 3 xor z shl 4)) xor ((sum xor y) + (k[(p and 3) xor e] xor z))

proc decrypt(v: var openArray[uint32], key: openArray[uint32]) =
  var sum, y, z: uint32
  var p, rounds, e: uint32
  let n = v.len
  rounds = (6 + 52 div n).uint32
  sum = (rounds * DELTA).uint32
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

proc encrypt(v: var openArray[uint32], key: openArray[uint32]) =
  var sum, y, z: uint32
  var p, rounds, e: uint32
  let n = v.len.uint32
  if n > 1:
    rounds = (6 + 52 div n).uint32
    sum = 0
    z = v[n - 1]
    for i in 0..<rounds:
      sum += DELTA
      e = (sum shr 2) and 3
      for p in 0'u..<(n - 1).uint32:
        y = v[p + 1]
        v[p] += mx(sum, y, z, p, e, key)
        z = v[p]
      p = n - 1
      y = v[0]
      v[n - 1] += mx(sum, y, z, p, e, key)
      z = v[n - 1]

proc computeHash(data: string): int32 =
  result = 0x6583463'i32
  for i in 0..<data.len:
    result += data[i].int32

template toOpenArr[Tin, Tout](arr: openArray[Tin], t: Tout): openArray[Tout] =
  var p = cast[ptr UncheckedArray[Tout]](arr[0].addr)
  p.toOpenArray(0, arr.len * sizeof(Tin) div sizeof(Tout) - 1)

proc loadSaveGame*(path: string): Savegame =
  var data = readFile(path)
  decrypt(data.toOpenArr(0'u32), savegameKey)

  let hashData = cast[ptr int32](data[^16].addr)[]
  let t = fromUnix(cast[ptr int32](data[^12].addr)[])
  
  let hashCheck = computeHash(data[0..^17])
  if hashData == hashCheck:
    result = Savegame(data: ggtableDecode(data), time: t)
  else:
    raise newException(HashError, "Invalid savegame")

proc saveSaveGame*(path: string, savegame: Savegame) =
  var data = ggtableEncode(savegame.data)
  let hash = computeHash(data)

  let fullSize = 500000
  let fullSizeAndFooter = fullSize + 16
  let marker = (8 - ((fullSize + 9) mod 8)).cint
  data.setLen fullSizeAndFooter

  # write at the end 16 bytes: hashdata (4 bytes) + savetime (4 bytes) + marker (8 bytes)
  var p = cast[ptr int32](data[^16].addr)
  p[] = hash
  p = cast[ptr int32](data[^12].addr)
  p[] = savegame.time.toUnix.int32
  memset(data[^8].addr, marker, 8)

  # then encode data
  encrypt(data.toOpenArr(0'u32), savegameKey)

  # and write data
  writeFile(path, data)
