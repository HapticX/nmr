import
  std/asyncdispatch,
  std/strformat,
  std/strscans,
  std/strutils,
  std/terminal,
  std/unicode,
  std/osproc,
  std/json,
  std/os,
  regex,
  ../utils,
  ../constants


proc removeCommand*(
    help: bool = false,
    global: bool = false,
    verbose: bool = false,
    recursive: bool = false,
    args: seq[string]
) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "remove", fgWhite, " <package(s)>\n"
    styledEcho "Install Nim package(s).\n"
    styledEcho "Aliases:"
    styledEcho fgYellow, "  r", fgWhite, ", ", fgYellow, "uninstall \n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, "  --help", fgWhite, "      Show this help"
    styledEcho fgYellow, "  -G", fgWhite, ",", fgYellow, "  --global", fgWhite, "    Remove package globally"
    styledEcho fgYellow, "  -R", fgWhite, ",", fgYellow, "  --recursive", fgWhite, " removes all dependencies of the package(s) if they become free.\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " remove ", fgRed, "norm"
    styledEcho fgYellow, "  nmr", fgMagenta, " r ", fgRed, "happyx pixie"
    return
  
  
  var
    package: Dependency
    nimbleFile = ""

  for file in walkFiles("*"):
    if file.endsWith(".nimble") and package.isNil:
      nimbleFile = file
      package = parseNimbleFile(file)
  
  var f = open(packagesFile, fmRead)
  let pkgs = parseJson(f.readAll())
  f.close()
  
  if not package.isNil:
    var f = open(nimbleFile, fmRead)
    var nimbleData = f.readAll()
    f.close()

    var
      depsToRemove: seq[Dependency] = @[]
      futures: seq[Future[void]]
    
    if args.len > 0:
      for i in args:
        var
          s = split(i, "@")
          version = ""
          op = ""
        let pkg = findPackage(s[0], pkgs)
        if s.len > 1:
          if s[1].scanf("\"$s${vop}$s$+\"", op, version):
            discard
          elif s[1].scanf("$s${vop}$s$+", op, version):
            discard
          else:
            version = s[1]
        var dep = Dependency(name: pkg["name"].str, version: version)

        if not pkg.isNil:
          futures.add processDep(dep, pkgs, true)
          depsToRemove.add dep
      
      waitFor waitAndProgress("Fetching packages", gather(futures))
    else:
      return

    for dep in depsToRemove:
      for directory in walkDirRec("deps", { pcDir }, {}):
        let dir = directory.lastPathPart
        if dir.startsWith(dep.name & '-'):
          removeDir(directory)
          nimbleData = nimbleData.replace(re2("requires\\s*\\(?\\s*\"\\s*" & dep.name & "[^\\n]+\\n"), "")
    
    f = open(nimbleFile, fmWrite)
    f.write(nimbleData)
    f.close()
    
    for file in walkDirRec(getCurrentDir()):
      if file.startsWith(getCurrentDir() / "deps"):
        continue
      var tmp: string
      if file.scanf("$*config.nims", tmp):
        let filepath = file.parentDir / "nimble.paths"
        if fileExists(filepath):
          f = open(filepath, fmRead)
          var data = f.readAll()
          f.close()
          for dep in depsToRemove:
            data = data.replace(re2("\\-\\-path:\"\\S*" & dep.name & "[^\\n]+\\n"), "")
          f = open(filepath, fmWrite)
          f.write(data)
          f.close()
