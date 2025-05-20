import
  std/strutils,
  std/terminal,

  ./commands/commands,
  ./utils,

  cligen,
  QRgen


proc helpCommandAux*(): int =
  helpCommand()
  QuitSuccess

proc upgradeCommandAux*(): int =
  upgradeCommand()
  QuitSuccess


proc mainMessage*() =
  stdout.eraseScreen()
  setCursorPos(0, 0)
  rightEcho fgYellow, " Documentation     "
  stdout.cursorUp()
  stdout.setCursorXPos(0)
  styledEcho fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1\n"
  styledEcho fgYellow, "A super-fast Nim package manager\n"

  styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "<command> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "help "
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "init ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "install ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "update ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "upgrade ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "remove ", fgBlue, "<package> ", fgWhite, "[options]"
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "deps-graph ", fgBlue, "<package> ", fgWhite, "[options]"

  let qr = newQR("clk.li/fhP") # https://github.com/HapticX/nmr
  qr.printTerminalBeaty(align = qraRight, flush = true)
  
  setCursorXPos(0)
  styledEcho "  - ",    fgYellow, "nmr ", fgMagenta, "publish ", fgBlue, "<package> ", fgWhite, "[options]\n"
  rightEcho fgYellow, "https://github.com/HapticX/nmr"



when isMainModule:
  dispatchMultiGen(
    [helpCommandAux, cmdName = "help"],
    [upgradeCommandAux, cmdName = "upgrade"],
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
  
  case subcmd
  of "help":
    quit(dispatchhelp(cmdLine = pars[1..^1]))
  of "upgrade", "up":
    quit(dispatchupgrade(cmdLine = pars[1..^1]))
  else:
    mainMessage()
    quit(QuitSuccess)
