import std/[streams, tables, strformat, parseopt, strutils]
import glob
import nimyggpack/ggtable_decoder, nimyggpack/range_stream, nimyggpack/xor_stream, nimyggpack/bnut_decoder

export newGGTableDecoder, newGGPackDecoder, ggtable_decoder.GGPackDecoder, ggtable_decoder.GGTableDecoder, extract, extractTable, newString
export newRangeStream
export newXorStream, xorKeys
export bnutEncode, bnutDecode

const
  Usage = """
nimyggpack - Tool to list files in ggpack files used in Thimbleweed Park.

Usage:
  nimyggpack [options]

Options:  
  --help,          -h        Shows this help and quits
  --key=key        -k        Name of the key to decrypt/encrypt the data.
                             Possible names: 56ad, 5bad, 566d, 5b6d, delores
  --list=pattern   -l        List files in a ggpack file
"""

proc list(pattern, path, xorKey: string) =
  echo fmt"list({pattern}, {path}, {xorKey})"
  let globPattern = glob(pattern)
  let decoder = newGGPackDecoder(newFileStream(path), xorKeys[xorKey])
  for (k, entry) in decoder.entries.pairs:
    if k.matches(globPattern):
      echo k

proc writeHelp() =
    echo Usage
    quit(0)

when isMainModule:
  var filename, pattern: string 
  var xorKey = "56ad"
  var cmdList: bool
  var p = initOptParser()
  # parse options
  for kind, key, val in p.getopt():
    case kind
    of cmdEnd: doAssert(false)
    of cmdShortOption, cmdLongOption:
      case normalize(key)
      of "h", "help":
        writeHelp()
      of "k", "key":
        xorKey = val
      of "l", "list":
        cmdList = true
        pattern = val
    of cmdArgument:
      filename = key
  if not cmdList or filename == "":
    writeHelp()
  else:
    list(pattern, filename, xorKey)