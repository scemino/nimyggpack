# Package

version       = "0.3.0"
author        = "scemino"
description   = "A simple library to list or extract files from ggpack files."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
binDir        = "bin"
bin           = @["nimyggpack"]

# Dependencies

requires "nim >= 1.6.2"
requires "glob >= 0.11.1"
