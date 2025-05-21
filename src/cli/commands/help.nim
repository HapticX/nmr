import
  std/terminal,
  ../utils


proc helpCommand*() =
  styledEcho fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1"
  styledEcho "Run `", fgYellow, "nmr ", fgMagenta, "<command>", fgYellow, " --help`", fgWhite, " for detailed usage.\n"
  styledEcho "Commands:"
  styledEcho fgMagenta, "  init", fgWhite, "           Initialize a new project"
  styledEcho fgMagenta, "  install", fgWhite, "        Install package(s) and deps"
  styledEcho fgMagenta, "  update", fgWhite, "         Update package(s) by semver"
  styledEcho fgMagenta, "  upgrade|up", fgWhite, "     Upgrade packages list to latest"
  styledEcho fgMagenta, "  remove", fgWhite, "         Remove package(s)"
  styledEcho fgMagenta, "  deps-graph|dg", fgWhite, "  Show dependency graph"
  styledEcho fgMagenta, "  publish", fgWhite, "        Publish a package"
  styledEcho fgMagenta, "  search|s", fgWhite, "       Search for packages"
  styledEcho fgMagenta, "  info", fgWhite, "           Shows info about package"
