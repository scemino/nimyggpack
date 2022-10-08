import std/times
import std/json
import std/algorithm
import std/sets
import ggtable_decoder
import ggtable_encoder
import btea

proc memset*(p: pointer, value: cint, size: csize_t) {.importc, header: "<string.h>".}

type
  Savegame* = object
    data*: JsonNode
    time*: Time
  HashError* = object of CatchableError

const savegameKey = [0xAEA4EDF3'u32, 0xAFF8332A'u32, 0xB5A2DBB4'u32, 0x9B4BA022'u32]

proc computeHash*(data: string): int32 =
  result = 0x6583463'i32
  for i in 0..<data.len:
    result += data[i].int32

template toOpenArr[Tin, Tout](arr: openArray[Tin], t: Tout): openArray[Tout] =
  var p = cast[ptr UncheckedArray[Tout]](arr[0].addr)
  p.toOpenArray(0, arr.len * sizeof(Tin) div sizeof(Tout) - 1)

proc loadSaveGame*(path: string): Savegame =
  var data = readFile(path)
  btDecrypt(data.toOpenArr(0'u32), savegameKey)

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
  btEncrypt(data.toOpenArr(0'u32), savegameKey)

  # and write data
  writeFile(path, data)
