import std/json
import std/strutils
import std/times
import std/parseutils
import btea
import savegame

const key = [0x2AAB9D93'u32, 0xAFF8562A'u32, 0xB5A2DBB4'u32, 0x2B4BA322'u32]

template toOpenArr[Tin, Tout](arr: openArray[Tin], t: Tout): openArray[Tout] =
  var p = cast[ptr UncheckedArray[Tout]](arr[0].addr)
  p.toOpenArray(0, arr.len * sizeof(Tin) div sizeof(Tout) - 1)

proc loadAchievements*(filename: string): JsonNode =
  var data = readFile(filename)
  btDecrypt(data.toOpenArr(0'u32), key)

  let marker = data[^1].int
  let content = data[0..^marker+11]
  result = newJObject()
  for line in content.splitLines():
    if line.len > 0:
      var name: string
      var pos = parseUntil(line, name, ':', 0) + 1
      pos += skipWhitespace(line, pos)
      let value = line[pos..^1]
      if value[0] == '"':
        result.add(name, newJString(value[1..^2]))
      else:
        result.add(name, newJInt(parseInt(value)))

proc toContent(node: JsonNode): string =
  for (k, v) in node.pairs:
    result.add(k)
    result.add(": ")
    case v.kind:
    of JString:
      result.add('"' & v.str & '"')
    of JInt:
      result.add($v.getInt())
    else:
      discard
    result.add('\n')

proc saveAchievements*(filename: string, node: JsonNode, time = getTime()) =
  var content = node.toContent()
  let fullSize = content.len
  let marker = 8 - ((fullSize + 9) mod 8)

  var buffer = newString(fullSize + 8 + marker + 2)
  copyMem(buffer[0].addr, content[0].addr, fullSize)

  # write at the end 16 bytes: hashdata (4 bytes) + savetime (4 bytes) + marker
  var p = cast[ptr int32](buffer[fullSize].addr)
  p[] = computeHash(content)
  p = cast[ptr int32](buffer[fullSize+4].addr)
  p[] = time.toUnix.int32
  for i in 0..marker+1:
    buffer[fullSize + 8 + i] = marker.char

  btEncrypt(buffer.toOpenArr(0'u32), key)
  writeFile(filename, buffer)
