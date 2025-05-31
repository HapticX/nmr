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
  zippy/ziparchives,
  ../utils,
  ../constants


proc installCommand*(
    help: bool = false,
    global: bool = false,
    verbose: bool = false,
    args: seq[string]
) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "install", fgWhite, " <package(s)>\n"
    styledEcho "Install Nim package(s).\n"
    styledEcho "Aliases:"
    styledEcho fgYellow, "  i \n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, "  --help", fgWhite, "              Show this help"
    styledEcho fgYellow, "  -G", fgWhite, ",", fgYellow, "  --global", fgWhite, "            Install package globally\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " install ", fgRed, "norm"
    styledEcho fgYellow, "  nmr", fgMagenta, " i ", fgRed, "happyx@#head pixie"
    return
  
  
  var
    package: Dependency
    nimbleFile = ""

  for file in walkFiles("*"):
    if file.endsWith(".nimble") and package.isNil:
      nimbleFile = file
      package = parseNimbleFile(file)
  
  if package.isNil:
    styledEcho fgRed, "Error: ", fgWhite, "this is not a nim package."

  var f = open(packagesFile, fmRead)
  let pkgs = parseJson(f.readAll())
  f.close()

  var
    deps: seq[Dependency]
    futures: seq[Future[void]]
  if args.len > 0:
    var insertIndex = -1
    var nimbleData: seq[string] = @[]
    if nimbleFile.len > 0:
      nimbleData = readFile(nimbleFile).splitLines
      for i, line in nimbleData.pairs():
        if line.startsWith("requires"):
          insertIndex = i+1
          break
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
        deps.add dep
    
    waitFor waitAndProgress("Fetching packages", gather(futures))

    for i in args:
      var
        s = split(i, "@")
        version = ""
        op = ""
      let pkg = findPackage(s[0], pkgs)
      for dep in deps:
        # Update .nimble file requires content
        if not pkg.isNil and dep.name.normalizedName == s[0] and nimbleData.len > 0 and not package.isNil:
          var canInsert = true
          for d in package.children:
            if d.name == dep.name:
              canInsert = false
              break
          if canInsert and insertIndex >= 0:
            nimbleData.insert("requires \"" & s[0] & " >= " & dep.version & "\"", insertIndex)
    if not global:
      if nimbleData.len > 0 and not package.isNil:
        writeFile(nimbleFile, nimbleData.join("\n"))
  else:
    var dep: Dependency
    for file in walkFiles("*"):
      if file.endsWith(".nimble") and dep.isNil:
        styledEcho fgYellow, "Dependency Graph", fgWhite, " of ", fgYellow, file.rsplit(".", 1)[0]
        dep = waitFor depsGraph(file, true)
        break
    if not dep.isNil:
      for d in dep.children:
        deps.add d
    else:
      styledEcho fgRed, "Error: ", fgWhite, "this is not a nim package."
      return

  futures = @[]
  for dep in deps:
    futures.add downloadDeps(dep, global)
  waitFor waitAndProgress("Download packages", gather(futures))

  var iDeps: seq[Dependency] = @[]
  for dep in deps:
    for i in dep.toInstallOrder:
      iDeps.add i

  for dep in iDeps:
    if verbose:
      styledEcho fgYellow, "   Info: ", fgWhite, "package ", fgYellow, dep.name, "-", dep.gitRef.name.split("/")[^1], fgWhite, " is installing ..."
    let
      depName = dep.name.normalizedName & "-" & dep.gitRef.name.split("/")[^1] & "-" & dep.gitRef.hash
      archiveFilename = ".cache/nmr/graph/" & depName & ".zip"
      depDirectory =
        if global:
          getHomeDir() / ".nimble" / "pkgs2" / depName
        else:
          "deps" / depName
    if not dirExists(depDirectory):
      extractAll(archiveFilename, depDirectory)
  
  if not global:
    var configFiles: seq[string] = @[]
    for i in walkDirRec(getCurrentDir()):
      if i.startsWith(getCurrentDir() / "deps"):
        continue
      var tmp: string
      if i.scanf("$*config.nims", tmp):
        configFiles.add i
      # When is not supporting
      # elif i.scanf("$*.nim.cfg", tmp):
      #   configFiles.add i
    updateConfigPaths(configFiles, iDeps, getCurrentDir() / "deps")
  else:
    for dep in iDeps:
      let
        depName = dep.name.normalizedName & "-" & dep.gitRef.name.split("/")[^1] & "-" & dep.gitRef.hash
        depDirectory = getHomeDir() / ".nimble" / "pkgs2" / depName
        first = firstFolder(depDirectory)
      moveFiles(first, depDirectory, true)
      var meta = %*{
        "version": 1,
        "metaData": {
          "url": dep.url,
          "downloadMethod": "git",
          "vcsRevision": dep.gitRef.hash[0..<40],
          "files": [],
          "binaries": [],
          "specialVersions": [ dep.version ]
        }
      }
      for i in walkDirRec(depDirectory):
        var file = i
        file.removePrefix(depDirectory)
        meta["metaData"]["files"].add %file
      var file = open(depDirectory / "nimblemeta.json", fmWrite)
      file.write(meta.pretty)
      file.close()

  styledEcho fgGreen, "Success: ", fgWhite, "package(s) was installed."
