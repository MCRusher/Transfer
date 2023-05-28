{.experimental: "codeReordering".}

import mummy, mummy/routers, mummy/fileloggers, webby
import net, nativesockets, strformat, strutils, os, times, parseopt

const FilesDir = "./files" # directory files are visible/served from
const LogsDir = "./logs" # directory where log files are stored
createDir(FilesDir)
createDir(LogsDir)

const IconData = slurp "./favicon.ico" # data of the favicon icon (read at compiletime)
const LogoData = slurp "./favicon.svg" # data of the logo image (read at compiletime)

const DefaultHost = $IPv4_any() # defaults to binding to all addresses
const DefaultPort = 80 # defaults to port 80, the default webserver port (should not have to enter it manually to connect)

var router: Router # router to store all route callbacks to

let log_filename = joinPath(LogsDir, $now()).addFileExt("log")
open(log_filename, fmWrite).close() # create new log file
var logger = newFileLogger(log_filename) # threaded logger that uses current date time as filename

var host = DefaultHost
var port = DefaultPort

router.get("/", index)
router.notFoundHandler = index
proc index(r: Request) =
    # the header of the main page content, unindented so that code folding will work in vscode
    var content = (&"""
        <!DOCTYPE html>
        <html>
        <meta name='viewport' content='width=device-width, height=device-height, initial-scale=1.0'>
        <body style="background-image:linear-gradient(red, yellow); min-height: 100vh;">
            <img src='/logo' onerror="this.src='/favicon.ico';" alt='T' style='border: thin solid white; width: 10%; height: 10%;'>

            <h3>Host Name: {getHostname()}</h3>
            <h3>Host Addr: {getPrimaryIPAddr()}:{port}</h3><br>

        <table border=2 cellpadding=5 cellspacing=5><tr>
    """).dedent()

    # iterate all of the files and add them to page content
    for kind, filename in walkDir(FilesDir, relative=true):
        if kind in {pcFile, pcLinkToFile}:
            content &= &"<td style='display: inline-block'><a href='/serve/{filename}'>{filename}</a></td>"
    content &= "\n</tr></table>\n</body>\n</html>"

    # respond with html page content
    r.respond(200, @[("Content-Type", "text/html; charset=utf-8")], content)

router.get("/serve/*", serveFile)
proc serveFile(r: Request) =
    # combine last part of uri with local directory to resolve full path
    let filename = joinPath(FilesDir, r.uri.parseUrl.paths[^1])
    let data = try: readFile(filename)
    except IOError:
        r.index() # file doesn't exist, defer to index page
        return
    
    # setting content type seems to be optional
    r.respond(200, @[("Content-Disposition", "attachment")], data) # send file data as an attachment

# inline route to serve favicon image when asked
router.get("/favicon.ico") do(r: Request):
    r.respond(200, @[("Content-Type", "image/vnd.microsoft.icon")], IconData)

# inline route to serve logo when asked, svg so it scales better
router.get("/logo") do(r: Request):
    r.respond(200, @[("Content-Type", "image/svg+xml")], LogoData)

# parse commandline arguments to allow overriding host and port values
for kind, key, val in getopt():
    if kind == cmdLongOption and key == "host" or
       kind == cmdShortOption and key == "h":
        host = val
    elif kind == cmdLongOption and key == "port" or
         kind == cmdShortOption and key == "p":
        try:
            port = val.parseInt()
        except ValueError:
            quit("Invalid Port")

newServer(router).serve(port.Port, host)