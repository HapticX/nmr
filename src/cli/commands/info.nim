import
  std/strutils,
  std/terminal,
  std/os,
  ../utils


proc infoCommand*(packages: seq[string]) =
  var dep: Dependency

  for file in walkFiles("*"):
    if file.endsWith(".nimble") and dep.isNil:
      dep = parseNimbleFile(file)
  
  if dep.isNil:
    styledEcho fgRed, "Error: ", fgWhite, "no any .nimble file here."
  else:
    styledEcho "Package:"
    styledEcho fgYellow, dep.name, " ", fgRed, " v" & dep.version
    styledEcho "\nDependencies:"
    for i in dep.children:
      stdout.write $i
