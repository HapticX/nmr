import
  std/asyncdispatch,
  std/strutils,
  std/terminal,
  std/json,
  std/os,
  ../utils


proc depsGraphCommand*(help: bool = false, packages: seq[string]) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "deps-graph ", fgRed, "<package>", fgWhite, " [options]\n"
    styledEcho "Generate and display the dependency graph.\n"
    styledEcho "Aliases:"
    styledEcho fgYellow, "  dg ", fgWhite, "|", fgYellow, " depsgraph\n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, " --help", fgWhite, "    Show this help\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " deps-graph", fgWhite, "          Shows deps graph of current package"
    styledEcho fgYellow, "  nmr", fgMagenta, " deps-graph", fgRed, " happyx", fgWhite, "   Shows deps graph of happyx package"
    return

  var dep: Dependency

  var f = open(packagesFile, fmRead)
  let pkgs = parseJson(f.readAll())
  f.close()

  if packages.len == 1:
    dep = Dependency(children: @[], name: packages[0])
    styledEcho fgYellow, "Dependency Graph", fgWhite, " of ", fgYellow, packages[0]
    waitFor waitAndProgress("Fetching packages", processDep(dep, pkgs))
    if dep.isNil:
      styledEcho fgRed, "Error: ", fgWhite, "no any .nimble file here."
    else:
      echo dep
  else:
    for file in walkFiles("*"):
      if file.endsWith(".nimble") and dep.isNil:
        styledEcho fgYellow, "Dependency Graph", fgWhite, " of ", fgYellow, file.rsplit(".", 1)[0]
        dep = waitFor depsGraph(file)
        break
    
    if dep.isNil:
      styledEcho fgRed, "Error: ", fgWhite, "no any .nimble file here."
    else:
      echo dep
