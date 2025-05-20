import
  std/asyncdispatch,
  std/strutils,
  std/terminal,
  std/json,
  std/os,
  ../utils


proc depsGraphCommand*(packages: seq[string]) =
  var dep: Dependency

  var f = open(packagesFile, fmRead)
  let pkgs = parseJson(f.readAll())
  f.close()

  if packages.len == 1:
    dep = Dependency(children: @[], name: packages[0])
    styledEcho fgYellow, "Dependency Graph", fgWhite, " of ", fgYellow, packages[0]
    waitFor waitAndProgress("Fetching packages", processDep(addr dep, addr pkgs))
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
