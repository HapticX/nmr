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


proc mainMessage*() =
  # centeredEcho fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1"
  # let qr = newQR("clk.li/fhP") # https://github.com/HapticX/nmr
  # qr.printTerminalBeaty

  # styledEcho "Usage: ", fgYellow, "nmr ", fgRed, "<command> ", fgWhite, "[options]"


  styledEcho fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1", fgYellow, "                                          Documentation      "
  styledEcho fgYellow, "                                                                      █▀▀▀▀▀█ ▀█▀█▀ █▀▀▀▀▀█"
  styledEcho "  Usage: ", fgYellow, "nmr ", fgRed, "<command> ", fgWhite, "[options]", fgYellow, "                                      █ ███ █  ██▄  █ ███ █"
  styledEcho fgYellow, "  - nmr init ", fgWhite, "[options]", fgYellow, "                                                █ ▀▀▀ █   ▀▄█ █ ▀▀▀ █"
  styledEcho fgYellow, "                                                                      ▀▀▀▀▀▀▀ █▄█▄█ ▀▀▀▀▀▀▀"
  styledEcho fgYellow, "                                                                      ▀█▄██ ▀▄ █▀ █▄█  ▄  ▀"
  styledEcho fgYellow, "                                                                      ▀▄██▀█▀▄█▀ ▄ ▄ ▄ ▀███"
  styledEcho fgYellow, "                                                                           ▀▀▀█▄█▄▄█  ▄▀ █▀"
  styledEcho fgYellow, "                                                                      █▀▀▀▀▀█  ▀▄▄██▄██▀▄  "
  styledEcho fgYellow, "                                                                      █ ███ █ █▀▄██▀▀▀▀▀   "
  styledEcho fgYellow, "                                                                      █ ▀▀▀ █ ▄▀   ██ ▀█▄██"
  styledEcho fgYellow, "                                                                      ▀▀▀▀▀▀▀ ▀▀▀▀ ▀       "


when isMainModule:
  dispatchMultiGen(
    [helpCommandAux, cmdName = "help"],
    [helpCommandAux, cmdName = "test"],
  )
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
  
  case subcmd
  of "help":
    quit(dispatchhelp(cmdLine = pars[1..^1]))
  else:
    mainMessage()
    quit(QuitSuccess)
