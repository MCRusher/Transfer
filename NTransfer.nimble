# Package

version       = "0.1.0"
author        = "MCRusher"
description   = "A simple and insecure file transfer application"
license       = "MIT"
srcDir        = "src"
bin           = @["Transfer"]


# Dependencies

requires "nim >= 1.9.3"
requires "mummy#HEAD"
requires "webby"

# tasks

# set application icon using rcedit on windows
when defined(windows):
    after build:
        exec("rcedit Transfer.exe --set-icon favicon.ico")