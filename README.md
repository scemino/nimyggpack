# nimyggpack

A simple command-line application to list or extract files from nimyggpack files, used by the [Thimbleweed Park](https://thimbleweedpark.com) game, which is an awesome adventure game, go buy it right now, you won't regret it (Steam, GOG).

## Build & Run

* clone the project: git clone https://github.com/scemino/nimyggpack.git
* build: `nim build`
* run: `./bin/nimyggpack --list="*.bnut" ThimbleweedPark.ggpack1`

That's it

## Usage

```
nimyggpack - Tool to list, extract files in ggpack files used in Thimbleweed Park.

  Usage:
    nimyggpack [options]

  Options:  
    --help,             -h        Shows this help and quits
    --key=key           -k        Name of the key to decrypt/encrypt the data.
                                  Possible names: 56ad, 5bad, 566d, 5b6d, delores
    --list=pattern      -l        Lists files in a ggpack file
    --extract=pattern   -x        Extracts files from a ggpack file
    --noconvert                   Disables auto conversion: .bnut to .nut, .wimpy to json, .byack to .yack
```

## Thanks

This project has been adapted from the awesome projects https://github.com/mrmacete/r2-ggpack and twp-ggdump https://github.com/mstr-/twp-ggdump

## Features

* Browse all files into the ggpack
* Search files with globbing
* Extract files from the ggpack
* Convert wimpy files to json
* Convert json files to wimpy files
* Convert bnut files to nut files
