import
  std/strutils,
  std/terminal,

  ./commands/commands,
  ./utils,

  cligen,
  QRgen


var
  hideQr = false


proc helpCommandAux*(): int =
  helpCommand()
  QuitSuccess


proc upgradeCommandAux*(hlp: bool = false): int =
  upgradeCommand(hlp)
  QuitSuccess


proc searchCommandAux*(hlp: bool = false, limit: int = 10, json: bool = false, args: seq[string]): int =
  if args.len == 0:
    styledEcho fgRed, "Error: ", fgWhite, "no search query provided.\n"
    styledEcho "Try `", fgYellow, "nmr ", fgMagenta, "search", fgYellow, " --help", fgWhite, "` for more information."
    return QuitSuccess
  searchCommand(hlp, limit, json, args)
  QuitSuccess


proc infoCommandAux*(args: seq[string]): int =
  infoCommand(args)
  QuitSuccess


proc depsGraphCommandAux*(hlp: bool = false, noCache: bool = false, args: seq[string]): int =
  depsGraphCommand(hlp, not noCache, args)
  QuitSuccess


proc installCommandAux*(hlp: bool = false, global: bool = false, verbose: bool = false, args: seq[string]): int =
  installCommand(hlp, global, verbose, args)
  QuitSuccess


proc removeCommandAux*(
    hlp: bool = false,
    global: bool = false,
    verbose: bool = false,
    recursive: bool = false,
    args: seq[string]
): int =
  removeCommand(hlp, global, verbose, recursive, args)
  QuitSuccess


proc cleanCacheCommandAux*(hlp: bool = false, skipNimble: bool = false, skipArchive: bool = false): int =
  cleanCacheCommand(hlp, skipNimble, skipArchive)
  QuitSuccess


proc initCommandAux*(
    hlp: bool = false,
    name: string = "",
    description: string = "Just another Nim package",
    version: string = "0.0.1",
    author: string = "",
    license: string = "MIT",
    minNimVersion: string = "1.6.14",
): int =
  initCommand(hlp, name, description, version, author, license, minNimVersion)
  QuitSuccess


proc mainMessage*() =
  stdout.eraseScreen()
  setCursorPos(0, 0)
  rightEcho fgYellow, " Documentation     "
  if hideQr:
    rightEcho fgYellow, "https://github.com/HapticX/nmr"
    stdout.cursorUp()
  stdout.cursorUp()
  stdout.setCursorXPos(0)
  styledEcho fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1\n"
  styledEcho fgYellow, "A super-fast Nim package manager\n"

  styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "<command> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "help "
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "init ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "install ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "update ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "upgrade "
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "remove ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "deps-graph ", fgBlue, "<package> ", fgWhite, "[options]"

  if not hideQr:
    let qr = newQR("clk.li/fhP") # https://github.com/HapticX/nmr
    qr.printTerminalBeaty(align = qraRight, flush = true)
  
    setCursorXPos(0)
    styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "publish ", fgBlue, "<package> ", fgWhite, "[options]\n"
    rightEcho fgYellow, "https://github.com/HapticX/nmr"
    stdout.cursorUp()
  else:
    styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "publish ", fgBlue, "<package> ", fgWhite, "[options]\n"

  stdout.cursorUp()
  setCursorXPos(0)
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "search ", fgBlue, "<query>"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "info ", fgBlue, "<package>"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "clean-cache\n"



when isMainModule:
  clCfg.opChars = {}
  clCfg.sepChars = {}
  dispatchMultiGen(
    [helpCommandAux, cmdName = "help"],
    [upgradeCommandAux, cmdName = "upgrade"],
    [searchCommandAux, cmdName = "search"],
    [infoCommandAux, cmdName = "info"],
    [depsGraphCommandAux, cmdName = "depsgraph"],
    [cleanCacheCommandAux, cmdName = "cleancache"],
    [initCommandAux, cmdName = "init"],
    [installCommandAux, cmdName = "install"],
    [removeCommandAux, cmdName = "remove"],
  )
  initCli()

  var pars = commandLineParams()
  let
    subcmd =
      if pars.len > 0 and not pars[0].startsWith("-"):
        pars[0]
      else:
        ""
  if pars.find("--no-emoji") != -1:
    pars.delete(pars.find("--no-emoji"))
    useEmoji = false
  if pars.find("--upgrade") != -1:
    pars.delete(pars.find("--upgrade"))
    fetchPackages()
  if pars.find("--hide-qr") != -1:
    pars.delete(pars.find("--hide-qr"))
    hideQr = true
  
  # Replace flags
  if pars.find("-l") != -1:
    let p = pars.find("-l")
    pars.delete(p)
    pars.insert("--limit", p)
  if pars.find("-n") != -1:
    let p = pars.find("-n")
    pars.delete(p)
    pars.insert("--name", p)
  if pars.find("-d") != -1:
    let p = pars.find("-d")
    pars.delete(p)
    pars.insert("--description", p)
  if pars.find("-nv") != -1:
    let p = pars.find("-nv")
    pars.delete(p)
    pars.insert("--min-nim-version", p)
  if pars.find("-A") != -1:
    let p = pars.find("-A")
    pars.delete(p)
    pars.insert("--author", p)
  if pars.find("-Li") != -1:
    let p = pars.find("-Li")
    pars.delete(p)
    pars.insert("--license", p)
  
  # Flags
  if pars.find("-G") != -1:
    pars.delete(pars.find("-G"))
    pars.add("--global")
  if pars.find("-j") != -1:
    pars.delete(pars.find("-j"))
    pars.add("--json")
  if pars.find("-v") != -1:
    pars.delete(pars.find("-v"))
    pars.add("--version")
  if pars.find("-V") != -1:
    pars.delete(pars.find("-V"))
    pars.add("--verbose")
  if pars.find("-sn") != -1:
    pars.delete(pars.find("-sn"))
    pars.add("--skip-nimble")
  if pars.find("-sa") != -1:
    pars.delete(pars.find("-sa"))
    pars.add("--skip-archive")
  if pars.find("-nc") != -1:
    pars.delete(pars.find("-nc"))
    pars.add("--no-cache")
  if pars.find("-R") != -1:
    pars.delete(pars.find("-R"))
    pars.add("--recursive")
  
  # Helo override
  if pars.find("-h") != -1:
    pars.delete(pars.find("-h"))
    pars.add("--hlp")
  if pars.find("--help") != -1:
    pars.delete(pars.find("--help"))
    pars.add("--hlp")
  
  case subcmd
  of "help", "h":
    quit(dispatchhelp(cmdLine = pars[1..^1]))
  of "upgrade", "up", "refresh":
    quit(dispatchupgrade(cmdLine = pars[1..^1]))
  of "search", "s":
    quit(dispatchsearch(cmdLine = pars[1..^1]))
  of "info":
    quit(dispatchinfo(cmdLine = pars[1..^1]))
  of "deps-graph", "depsgraph", "dg":
    quit(dispatchdepsgraph(cmdLine = pars[1..^1]))
  of "clean-cache", "cleancache", "clnc", "cache-clean", "cacheclean":
    quit(dispatchcleancache(cmdLine = pars[1..^1]))
  of "init":
    quit(dispatchinit(cmdLine = pars[1..^1]))
  of "install", "i":
    quit(dispatchinstall(cmdLine = pars[1..^1]))
  of "remove", "r", "uninstall":
    quit(dispatchremove(cmdLine = pars[1..^1]))
  else:
    if pars.find("--hlp") != -1:
      quit(dispatchhelp(cmdLine = pars[1..^1]))
    else:
      mainMessage()
      quit(QuitSuccess)
