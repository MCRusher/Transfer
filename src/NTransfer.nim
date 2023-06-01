{.experimental: "codeReordering".}

import mummy, mummy/routers, mummy/fileloggers, webby
import net, nativesockets, strformat, strutils, os, times, parseopt, browsers

const FilesDir = "./files" # directory files are visible/served from
const LogsDir = "./logs" # directory where log files are stored
createDir(FilesDir)
createDir(LogsDir)

const LogoData = slurp "logo.svg" # data of the logo image (read at compiletime)

const DefaultHost = $IPv4_any() # defaults to binding to all addresses
const DefaultPort = 80 # defaults to port 80, the default webserver port (should not have to enter it manually to connect)

var router: Router # router to store all route callbacks to

# threaded logger that uses current date time as filename
var logger = newFileLogger(joinPath(LogsDir, now().format("yyyy-MM-dd'_'HH'h'mm'm'ss's'")).addFileExt("log"))

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
        <head>
            <link rel="icon" type="image/svg+xml" href="/logo.svg" sizes="16x16">
            <title>Transfer</title>
        </head>
        <body style="background-image:linear-gradient(yellow, red); min-height: 100vh;">
            <img src='/logo.svg' alt='T' style='border: thin solid white; width: 10%; height: 10%;'>

            <h3>Host Name: {getHostname()}</h3>
            <h3>Host Addr: {getPrimaryIPAddr()}:{port}</h3><br>

        <table border=2 cellpadding=5 cellspacing=5><tr>
    """).dedent()

    # iterate all of the files and add them to page content
    for kind, filename in walkDir(FilesDir, relative=true):
        if kind in {pcFile, pcLinkToFile}:
            content &= &"<td style='display: inline-block'><a href='/serve/{filename}'>{filename}</a></td>"
    content &= """</tr></table><br><hr><br><button onclick="window.location.href='/shutdown'">Shutdown</button></body></html>"""

    # respond with html page content
    r.respond(200, @[("Content-Type", "text/html; charset=utf-8")], content)

router.get("/serve/*", serveFile)
proc serveFile(r: Request) =
    # combine last part of uri with local directory to resolve full path
    let filename = joinPath(FilesDir, r.uri.parseUrl.paths[^1])
    let data = try: readFile(filename)
    except IOError:
        logger.info(&"Failed to serve file \"{filename}\" to client \"{r.remoteAddress}\"")
        r.index() # file doesn't exist, defer to index page
        return
    
    # setting content type seems to be optional
    logger.info(&"Served file \"{filename}\" to client \"{r.remoteAddress}\"")
    r.respond(200, @[("Content-Disposition", "attachment")], data) # send file data as an attachment

# inline route to serve logo (used for favicon as well) when asked, svg so it scales better
router.get("/logo.svg") do(r: Request):
    r.respond(200, @[("Content-Type", "image/svg+xml")], LogoData)

# inline route to shut down the server
router.get("/shutdown") do(r: Request):
    logger.info(&"Server shutdown initiated by client \"{r.remoteAddress}\"")
    r.respond(200, @[("Content-Type", "text/html; charset=utf-8")], """
    <!DOCTYPE html>
    <html>
        <body>
            <h1>Server is dead.</h1>
        </body>
    </html>
    """.dedent())
    quit(QuitSuccess)
    

var openBrowser = true
# parse commandline arguments to allow overriding host and port values
for kind, key, val in getopt(shortNoVal= {'b'}, longNoVal= @["no-browser"]):
    if kind == cmdLongOption and key == "host" or
       kind == cmdShortOption and key == "h":
        host = val
    elif kind == cmdLongOption and key == "port" or
         kind == cmdShortOption and key == "p":
        try:
            port = val.parseInt()
        except ValueError:
            quit("Invalid Port")
    elif kind == cmdLongOption and key == "no-browser" or
         kind == cmdShortOption and key == "b":
            openBrowser = false


var server_thrd: Thread[(Router, int, string)]
server_thrd.createThread(param=(router, port, host), tp=proc(args: (Router, int, string)) =
    let (router, port, host) = args
    newServer(router).serve(port.Port, host)
)

# if the server is listening on localhost, open the host's browser to the page automatically
# unless told not to by commandline args
if openBrowser and host in [$IPv4_any(), $IPv6_any(), "127.0.0.1"]:
    openDefaultBrowser(&"http://127.0.0.1:{port}")

server_thrd.joinThread()