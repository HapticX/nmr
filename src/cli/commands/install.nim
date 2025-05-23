import
  std/asyncdispatch,
  std/strformat,
  std/strscans,
  std/strutils,
  std/terminal,
  std/unicode,
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
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, "  --help", fgWhite, "              Show this help\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " install ", fgRed, "norm"
    styledEcho fgYellow, "  nmr", fgMagenta, " i ", fgRed, "happyx pixie"
    return
  
  
  var package: Dependency

  for file in walkFiles("*"):
    if file.endsWith(".nimble") and package.isNil:
      package = parseNimbleFile(file)
  
  if package.isNil:
    styledEcho fgRed, "Error: ", fgWhite, "this is not a nim package."

  var f = open(packagesFile, fmRead)
  let pkgs = parseJson(f.readAll())
  f.close()

  var deps: seq[Dependency]
  var pDeps: seq[ptr Dependency]
  var futures: seq[Future[void]]
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
    var dep = Dependency(name: pkg["name"].str, op: op, version: version)
    if not pkg.isNil:
      futures.add processDep(dep, pkgs, true)
    pDeps.add addr dep
  waitFor waitAndProgress("Fetching packages", gather(futures))

  for dep in pDeps:
    deps.add dep[]

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
      depName = dep.name & "-" & dep.gitRef.name.split("/")[^1] & "-" & dep.gitRef.hash
      archiveFilename = ".cache/nmr/graph/" & depName & ".zip"
      depDirectory = "deps/" & depName
    if not dirExists(depDirectory):
      extractAll(archiveFilename, depDirectory)
  
  var configFiles: seq[string] = @[]
  for i in walkDirRec(getCurrentDir()):
    if i.startsWith(getCurrentDir() / "deps"):
      continue
    var tmp: string
    if i.scanf("$*config.nims", tmp):
      configFiles.add i
    elif i.scanf("$*.nim.cfg", tmp):
      configFiles.add i
  
  updateConfigPaths(configFiles, iDeps, getCurrentDir() / "deps")

  styledEcho fgGreen, "Success: ", fgWhite, "package(s) was installed."
