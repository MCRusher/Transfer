# Package

version       = "0.1.0"
author        = "MCRusher"
description   = "A simple and insecure file transfer application"
license       = "MIT"
srcDir        = "src"
bin           = @["NTransfer"]


# Dependencies

requires "nim >= 1.9.3"
requires "mummy"
requires "webby"