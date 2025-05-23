import
  std/asyncdispatch,
  std/httpclient,
  std/asyncfile,
  std/strformat,
  std/terminal,
  std/strutils,
  std/strscans,
  std/unicode,
  std/macros,
  std/tables,
  std/osproc,
  std/json,
  std/os,

  zippy/ziparchives,
  taskpools,
  QRgen/private/Drawing,
  QRgen,

  ./textutils,
  ./git_utils,
  ./async_utils,
  ./semver,
  ./types


export
  textutils,
  async_utils,
  types


const PACKAGES = "https://raw.githubusercontent.com/nim-lang/packages/refs/heads/master/packages.json"


var
  repoRefs* = newTable[string, seq[tuple[hash, name: string]]]()


proc createFile*(filename, content: string) =
  var f = open(filename, fmWrite)
  f.write(content)
  f.close()


proc printTerminalBeaty*(
    self: DrawedQRCode,
    clr: ForegroundColor = fgYellow,
    align: QrAlign = qraCenter,
    flush: bool = false
) =
  ## Print a `DrawedQRCode` to the terminal using `stdout`.
  let
    size = self.drawing.size
    width = terminalWidth()
    ESC = "\x1b["
    padding =
      case align
      of qraLeft: 0
      of qraCenter: (width - self.drawing.size.int) div 2
      of qraRight: (width - self.drawing.size.int) - 1
  var result: string = newStringOfCap((size.uint16 * 2 + 11) * size + 10)
  stdout.setForegroundColor(clr)
  if not flush:
    result.add "\n"
  else:
    for y in countup(0, size.int, 2):
      stdout.cursorUp()
  for y in countup(0, size.int, 2):
    if flush:
      stdout.cursorDown()
      setCursorXPos(padding)
    else:
      result.add " ".repeat(padding)
    for x in 0..<size.int:
      let top    = self.drawing[x.uint8, y.uint8]
      let bottom = if y.uint8+1 < size.uint8: self.drawing[x.uint8, y.uint8+1] else: false
      let ch =
        if top and bottom:
          "█"
        elif top:
          "▀"
        elif bottom:
          "▄"
        else:
          " "
      if flush:
        stdout.write ch
      else:
        result.add ch
    if flush:
      discard # stdout.cursorDown()
    else:
      result.add "\n"
  if not flush:
    result.add "\n"
    stdout.write result
  stdout.resetAttributes()


proc fetchPackages*() =
  waitFor waitAndProgress("Fetching packages", newAsyncHttpClient().downloadFile(
    PACKAGES, getDataDir() / "nmr" / "packages.json"
  ))
  styledEcho fgCyan, "[Fetching packages]", fgGreen, " Completed"


proc initCli*() =
  # Data directory
  if not dirExists(getDataDir() / "nmr"): createDir(getDataDir() / "nmr")

  # local dependencies directory
  if not dirExists("deps"): createDir("deps")

  # local cache directory
  if not dirExists(".cache"): createDir(".cache")
  if not dirExists(".cache/nmr"): createDir(".cache/nmr")
  if not dirExists(".cache/nmr/graph"): createDir(".cache/nmr/graph")
  
  # fetch actual package list if it doesn't exists
  if not fileExists(packagesFile): fetchPackages()


proc vop*(input: string; strVal: var string; start: int): int =
  # matches exactly ``n`` digits. Matchers need to return 0 if nothing
  # matched or otherwise the number of processed chars.
  if start+1 < input.len and input[start..start+1] in [">=", "<=", "~=", "==", "^="]:
    result = 2
    strVal = input[start..start+1]
  elif start < input.len and input[start] in {'<', '>', '@'}:
    result = 1
    strVal = $input[start]


proc parseNimbleFile*(filename: string): Dependency =
  if not fileExists(filename):
    return nil

  let (dir, name, ext) = filename.splitFile()
  var
    tmp = ""
    version = ""
    srcDir = ""
    f = open(filename, fmRead)
  let data = f.readAll()
  f.close()
  
  result = Dependency(children: @[], name: name, version: version, parent: nil)

  for i in data.split("\n"):
    if i.scanf("srcDir$s=$s\"$*\"", srcDir):
      result.srcDir = srcDir
    elif i.scanf("version$s=$s\"$*\"", version):
      result.version = version
    else:
      var
        pkg, op, version: string
      if i.scanf("requires$s\"$w$s${vop}$s$*\"", pkg, op, version):
        discard
      elif i.scanf("requires$s\"$*\"", pkg):
        op = ""
        version = ""
      if pkg.len > 0 and version.len > 0 and pkg.toLower() != "nim":
        result.children.add Dependency(parent: result, children: @[], name: pkg, op: op, version: version)


proc findPackage*(name: string, packages: JsonNode): JsonNode =
  var pkg: JsonNode
  for package in packages:
    if "name" in package and name.toLower() == package["name"].str.toLower():
      pkg = package
      if "alias" in pkg:
        pkg = findPackage(pkg["alias"].str, packages)
      break
  pkg


proc updateConfigPaths*(
    configFiles: seq[string],
    deps: seq[Dependency],
    depsRoot: string
) =
  ## For each config file, update only those `--path:"..."` lines
  ## that refer to an existing dependency (by dirName), leaving others intact.
  ## If a dep has no matching line, we insert it after the header comments.
  for cfgPath in configFiles:
    let cfgDir = parentDir(cfgPath)
    var relDeps = relativePath(depsRoot, cfgDir)
    relDeps = relDeps.replace(DirSep, '/')

    # read and split
    let original = readFile(cfgPath).splitLines()
    var lines = original[0..^1]

    # find insertion index (after leading comment lines)
    var insertAt = 0
    while insertAt < lines.len and lines[insertAt].strip().startsWith("#"):
      insertAt.inc

    # process each dependency
    for dep in deps:
      # build dirName and fullPath
      let tagPart = dep.gitRef.name.split('/')[^1]
      let dirName = fmt"{dep.name}-{tagPart}-{dep.gitRef.hash}"
      var fullPath = fmt"{relDeps}/{dirName}"
      # if there's exactly one subdir under depsRoot/dirName, use it
      let dr = depsRoot / dirName
      var subDir = ""
      var cnt = 0
      for kind, p in walkDir(dr):
        if kind == pcDir:
          subDir = p.split(DirSep)[^1]
          cnt.inc
      if cnt == 1:
        fullPath.add "/" & subDir
      if dep.srcDir.len > 0:
        fullPath.add "/" & dep.srcDir

      let desiredLine = "--path:\"" & fullPath & "\""
      var replaced = false

      # replace any existing line for this dep
      for i in 0..<lines.len:
        if lines[i].startsWith("--path:\"") and lines[i].contains(dirName):
          lines[i] = desiredLine
          replaced = true

      # if none replaced, insert a new line
      if not replaced:
        lines.insert(desiredLine, insertAt)
        insertAt.inc

    # write back
    writeFile(cfgPath, lines.join("\n"))


proc processDep*(dep: Dependency, packages: JsonNode, useCache: bool = true) {.async.} =
  var pkg = findPackage(dep.name, packages)
  if pkg.isNil:
    return
  var client = newAsyncHttpClient()
  if "method" in pkg:
    case pkg["method"].str
    of "hg":
      discard
    of "git":
      var ghPath = pkg["url"].str.split("github.com/")[1]
      ghPath.removeSuffix(".git")
      var gitRef: tuple[hash, name: string]
      if ghPath notin repoRefs:
        repoRefs[ghPath] = await getRefs(pkg["url"].str)
      gitRef = repoRefs[ghPath].findTag(dep.op, dep.version)
      dep.gitRef = gitRef
      dep.url = pkg["url"].str
      let
        url = "https://raw.githubusercontent.com/" & ghPath & "/" & gitRef.name & "/" & pkg["name"].str & ".nimble"
        filename = ".cache/nmr/graph/" & dep.name & "-" & gitRef.name.split("/")[^1] & "-" & gitRef.hash & ".nimble"
      if not useCache or not fileExists(filename):
        var data = await client.get(url)
        if data.code == Http200:
          var f = openAsync(filename, fmWrite)
          await f.write(await data.body)
          f.close()
        else:
          let
            urlZip = "https://github.com/" & ghPath & "/archive/" & gitRef.name & "/" & pkg["name"].str & ".zip"
            filenameZip = ".cache/nmr/graph/" & ghPath.split("/")[1] & ".zip"
          await client.downloadFile(urlZip, filenameZip)
          # walk through .zip
          let reader = openZipArchive(filenameZip)
          try:
            var archiveFile = ""
            for file in reader.walkFiles:
              if file.endsWith(".nimble"):
                archiveFile = file
                break
            if archiveFile.len > 0:
              let data = reader.extractFile(archiveFile)
              var f = openAsync(filename, fmWrite)
              await f.write(data)
              f.close()
          finally:
            reader.close()
      
      var currentDep = parseNimbleFile(filename)
      if currentDep.isNil:
        return
      
      dep.version = currentDep.version
      dep.op = currentDep.op
      dep.srcDir = currentDep.srcDir
      
      var childFuts: seq[Future[void]] = @[]
      for nextDep in currentDep.children:
        childFuts.add processDep(nextDep, packages, useCache)
        dep.children.add nextDep
      await gather(childFuts)


proc downloadDeps*(dep: Dependency, global: bool = false) {.async.} =
  var
    repoUrl = dep.url
    client = newAsyncHttpClient()
  repoUrl.removeSuffix(".git")
  let
    urlZip = repoUrl & "/archive/" & dep.gitRef.name & "/" & dep.name & ".zip"
    filenameZip = ".cache/nmr/graph/" & dep.name & "-" & dep.gitRef.name.split("/")[^1] & "-" & dep.gitRef.hash & ".zip"
  if fileExists(filenameZip):
    return
  await client.downloadFile(urlZip, filenameZip)

  var futures: seq[Future[void]] = @[]
  for dep in dep.children:
    futures.add downloadDeps(dep)
  await gather(futures)


proc depsGraph*(filename: string, useCache: bool = true): Future[Dependency] {.async.} =
  var f = openAsync(packagesFile, fmRead)
  let packages = parseJson(await f.readAll())
  f.close()
  
  result = parseNimbleFile(filename)

  if result.isNil:
    return result

  var rootFuts: seq[Future[void]] = @[]
  for dep in result.children:
    rootFuts.add processDep(dep, packages, useCache)
  await gather(rootFuts)
