import std/[streams, tables, strformat, times]
import glob
import nimyggpackpkg/ggtable_decoder, nimyggpackpkg/range_stream,
    nimyggpackpkg/xor_stream, nimyggpackpkg/bnut_decoder, nimyggpackpkg/ggpack_decoder,
    nimyggpackpkg/ggtable_encoder, nimyggpackpkg/ggpack_writer, nimyggpackpkg/savegame
import nimyggpackpkg/achievement

export newGGTableDecoder, newGGPackDecoder, newGGTableEncoder, newGGPackWriter,
    ggpack_decoder.GGPackDecoder, ggtable_decoder.GGTableDecoder, extract,
    extractTable, newString, ggtable_encoder.writeTable,
    ggpack_writer.write, ggpack_writer.close
export newRangeStream
export newXorDecodeStream, newXorEncodeStream, xorKeys, xorDecode, xorEncode
export bnutEncode, bnutDecode
export ggtableEncode, ggtableDecode
export Savegame
export loadSaveGame, saveSaveGame
export loadAchievements, saveAchievements

when isMainModule:
  import std/[parseopt, strutils, os, json]

  const
    Usage = """
  nimyggpack - Tool to list, extract files in ggpack files used in Thimbleweed Park.

  Usage:
    nimyggpack [options]

  Options:  
    --help,             -h        Shows this help and quits
    --key=key           -k        Name of the key to decrypt/encrypt the data.
                                  Possible names: 56ad, 5bad, 566d, 5b6d, delores
    --list=pattern      -l        Lists files in a ggpack file
    --extract=pattern   -x        Extracts files from a ggpack file
    --savetojson=file   -st       Extracts savegame to json
    --savefromjson=file -sf       Creates savegame from json
    --achtojson=file    -at       Extracts Save.dat to json
    --achfromjson=file  -af       Creates Save.dat from json
    --noconvert                   Disables auto conversion: .bnut to .nut, .wimpy to json, .byack to .yack
  """

  type
    Command = enum
      cmdList, cmdExtract, cmdUpdate, cmdSaveToJson, cmdSaveFromJson, cmdAchToJson, cmdAchFromJson
    Settings = object
      filename, pattern: string
      xorKey: string
      cmd: Command
      noconvert: bool

  proc doList(settings: Settings) =
    echo fmt"list({settings.pattern}, {settings.filename}, {settings.xorKey})"
    let globPattern = glob(settings.pattern)
    let decoder = newGGPackDecoder(newFileStream(settings.filename), xorKeys[settings.xorKey])
    for (k, entry) in decoder.entries.pairs:
      if k.matches(globPattern):
        echo k
  
  proc convert(self: GGPackDecoder, filename: string) =
    let (dir, name, ext) = splitFile(filename)
    case ext.toLower
    of ".bnut":
      let f = open(joinPath(dir, name & ".nut"), fmWrite)
      f.write bnutDecode(self.extract(filename).readAll)
      f.close
    of ".byack":
      let f = open(joinPath(dir, name & ".yack"), fmWrite)
      f.write self.extract(filename).readAll
      f.close
    of ".wimpy":
      let f = open(filename, fmWrite)
      f.write pretty(self.extractTable(filename))
      f.close
    else:
      let f = open(filename, fmWrite)
      f.write self.extract(filename).readAll
      f.close
  
  proc doExtract(settings: Settings) =
    echo fmt"extract({settings.pattern}, {settings.filename}, {settings.xorKey})"
    let globPattern = glob(settings.pattern)
    let decoder = newGGPackDecoder(newFileStream(settings.filename), xorKeys[settings.xorKey])
    for (k, entry) in decoder.entries.pairs:
      if k.matches(globPattern):
        if settings.noconvert:
          let f = open(k, fmWrite)
          f.write decoder.extract(k).readAll
          f.close
        else:
          convert(decoder, k)

  proc doSaveToJson(settings: Settings) =
    var fn = settings.pattern
    let savegame = loadSaveGame(fn)
    fn = changeFileExt(fn, ".json")
    writeFile(fn , pretty(savegame.data))

  proc doAchToJson(settings: Settings) =
    var fn = settings.pattern
    let ach = loadAchievements(fn)
    fn = changeFileExt(fn, ".json")
    writeFile(fn , pretty(ach))

  proc doSaveFromJson(settings: Settings) =
    var fn = settings.pattern
    let json = parseFile(fn)
    let savetime = fromUnix(json["savetime"].getInt)
    let savegame = Savegame(data: json, time: savetime)
    fn = changeFileExt(fn, ".save")
    saveSaveGame(fn, savegame)

  proc doAchFromJson(settings: Settings) =
    var fn = settings.pattern
    let json = parseFile(fn)
    fn = changeFileExt(fn, ".dat")
    saveAchievements(fn, json)

  proc doUpdate(settings: Settings) =
    echo fmt"update({settings.pattern}, {settings.filename}, {settings.xorKey})"
    let backupFilename = settings.filename & ".bak"
    let globPattern = glob(settings.pattern)
    moveFile(settings.filename, backupFilename)
    let decoder = newGGPackDecoder(newFileStream(backupFilename), xorKeys[settings.xorKey])
    let fs = newFileStream(settings.filename, fmWrite)
    var writer = newGGPackWriter(fs, xorKeys[settings.xorKey])
    for (k, entry) in decoder.entries.pairs:
      echo "Adding " & k & "..."
      if k.matches(globPattern):
        let f = open(k, fmRead)
        writer.write(k, f.readAll)
        f.close
      else:
        writer.write(k, decoder.extract(k).readAll)
    writer.close
    fs.close

  proc writeHelp() =
    echo Usage
    quit(0)
      
  proc checkFilename(settings: Settings): bool =
    if settings.filename == "":
      writeHelp()
      result = false
    else:
      result = true

  var settings = Settings(xorKey: "56ad")
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
        settings.xorKey = val
      of "l", "list":
        settings.cmd = cmdList
        settings.pattern = val
      of "x", "extract":
        settings.cmd = cmdExtract
        settings.pattern = val
      of "u", "update":
        settings.cmd = cmdUpdate
        settings.pattern = val
      of "st", "savetojson":
        settings.cmd = cmdSaveToJson
        settings.pattern = val
      of "sf", "savefromjson":
        settings.cmd = cmdSaveFromJson
        settings.pattern = val
      of "at", "achtojson":
        settings.cmd = cmdAchToJson
        settings.pattern = val
      of "af", "achfromjson":
        settings.cmd = cmdAchFromJson
        settings.pattern = val
      of "noconvert":
        settings.noconvert = true
    of cmdArgument:
      settings.filename = key
  
  case settings.cmd:
  of cmdList:
    if checkFilename(settings):
      doList(settings)
  of cmdExtract:
    if checkFilename(settings):
      doExtract(settings)
  of cmdUpdate:
    if checkFilename(settings):
      doUpdate(settings)
  of cmdSaveToJson:
    doSaveToJson(settings)
  of cmdSaveFromJson:
    doSaveFromJson(settings)
  of cmdAchToJson:
    doAchToJson(settings)
  of cmdAchFromJson:
    doAchFromJson(settings)
