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
  ./types


export
  textutils,
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


proc downloadParallel(filename: string): bool =
  try:
    downloadFile(newHttpClient(), PACKAGES, filename)
  except:
    echo getCurrentExceptionMsg()
  return true


proc waitAndProgress*[T](action: string, fv: Flowvar[T], color: ForegroundColor = fgCyan) =
  var
    i = 0
    progresses = @["/", "-", "\\", "|"]
  while not fv.isReady:
    styledEcho color, "[", action, "] ", fgWhite, progresses[i]
    if i == progresses.len-1:
      i = 0
    else:
      inc i
    sleep(50)
    stdout.flushFile()
    stdout.cursorUp()


proc waitAndProgress*[T](action: string, fut: Future[T], color: ForegroundColor = fgCyan) {.async.} =
  var
    i = 0
    progresses = @["/", "-", "\\", "|"]
  while not fut.finished and not fut.failed:
    styledEcho color, "[", action, "] ", fgWhite, progresses[i]
    if i == progresses.len-1:
      i = 0
    else:
      inc i
    await sleepAsync(50)
    stdout.flushFile()
    stdout.cursorUp()
  styledEcho fgCyan, "[", action, "]", fgGreen, " Completed"


proc fetchPackages*() =
  var tp = Taskpool.new(countProcessors())
  var x = tp.spawn downloadParallel(getDataDir() / "nmr" / "packages.json")
  waitAndProgress("Fetching packages", x)
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


proc gather*[T](futs: openarray[Future[T]]): auto =
  when T is void:
    var
      retFuture = newFuture[void]("asyncdispatch.gather")
      completedFutures = 0

    let totalFutures = len(futs)

    for fut in futs:
      fut.addCallback proc (f: Future[T]) =
        inc(completedFutures)
        if not retFuture.finished:
          if f.failed:
            retFuture.fail(f.error)
          else:
            if completedFutures == totalFutures:
              retFuture.complete()

    if totalFutures == 0:
      retFuture.complete()

    return retFuture

  else:
    var
      retFuture = newFuture[seq[T]]("asyncdispatch.gather")
      retValues = newSeq[T](len(futs))
      completedFutures = 0

    for i, fut in futs:
      proc setCallback(i: int) =
        fut.addCallback proc (f: Future[T]) =
          inc(completedFutures)
          if not retFuture.finished:
            if f.failed:
              retFuture.fail(f.error)
            else:
              retValues[i] = f.read()

              if completedFutures == len(retValues):
                retFuture.complete(retValues)

      setCallback(i)

    if retValues.len == 0:
      retFuture.complete(retValues)

    return retFuture


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


proc parseVersion*(v: string): seq[int] =
  var s = v.strip()
  if s.startsWith("refs/tags/"):
    s = s.split('/')[^1]
  var tmpS = s
  s = ""
  for i in tmpS:
    if i in {'0'..'9', '.'}:
      s &= i
  # strip leading "v"
  if s.startsWith("v"):
    s = s[1 .. ^1]
  let parts = s.split('.')
  result.setLen(parts.len)
  for i, p in parts:
    result[i] = p.parseInt()

proc cmpVersion*(a, b: seq[int]): int =
  let n = max(a.len, b.len)
  for i in 0..<n:
    let ai = if i < a.len: a[i] else: 0
    let bi = if i < b.len: b[i] else: 0
    if ai < bi: return -1
    if ai > bi: return 1
  return 0

proc tagParts(tn: string): tuple[rf: string, pv: seq[int]] =
  let name = if tn.startsWith("refs/tags/"): tn.split('/')[^1] else: tn
  (tn, parseVersion(name))


proc findTag*(refs: seq[tuple[hash, name: string]], op, version: string): tuple[hash, name: string] =
  ## Select a git ref (tag or head) from `refs` according to `op` and `version`.
  ## If both `op` and `version` are empty, pick the highest‐semver tag.

  # split into tags and heads
  var tags, heads: seq[tuple[hash, name: string]]
  for r in refs:
    if r.name.startsWith("refs/tags/"): tags.add r
    elif r.name.startsWith("refs/heads/"): heads.add r

  # 1) no op & no version: pick highest semver tag
  if op.len == 0 and version.len == 0:
    if tags.len > 0:
      # find max by semver
      var best = tags[0]
      var bestV = tagParts(best.name).pv
      for t in tags[1..^1]:
        let (_, tv) = tagParts(t.name)
        if cmpVersion(tv, bestV) == 1:
          best = t
          bestV = tv
      return best
    else:
      return refs[0]

  # 2) HEAD shortcut
  if version[0] == '#' and version[1..^1].toLowerAscii().strip() == "head":
    return refs[0]
  elif version.toLowerAscii().strip() == "head":
    return refs[0]

  # 3) direct "#hash" syntax
  let libhash = version.split("#")
  if libhash.len == 2:
    return (hash: "", name: libhash[1])

  # 4) semver operator on tags
  if op.len > 0 and version.len > 0:
    let pv = parseVersion(version)
    var candidates: seq[tuple[hash, name: string]]

    case op
    of ">":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) == 1: candidates.add t
    of "<":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) == -1: candidates.add t
    of ">=":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) >= 0: candidates.add t
    of "<=":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) <= 0: candidates.add t
    of "~=":
      var bump = pv
      if bump.len >= 2: bump[1] += 1 else: bump[0] += 1
      for t in tags:
        let tv = tagParts(t.name).pv
        if cmpVersion(tv, pv) >= 0 and cmpVersion(tv, bump) < 0:
          candidates.add t
    of "^=":
      var bound: seq[int]
      if pv.len >= 1 and pv[0] != 0:
        bound = @[pv[0] + 1]
      elif pv.len >= 2 and pv[1] != 0:
        bound = @[0, pv[1] + 1]
      elif pv.len >= 3:
        bound = @[0, 0, pv[2] + 1]
      else:
        bound = @[pv[0] + 1]
      for t in tags:
        let tv = tagParts(t.name).pv
        if cmpVersion(tv, pv) >= 0 and cmpVersion(tv, bound) < 0:
          candidates.add t
    of "==":
      let want = parseVersion(version).join(".")
      for t in tags:
        let nm = if t.name.startsWith("refs/tags/"): t.name.split('/')[^1] else: t.name
        if nm == want:
          return t
    else:
      discard

    if candidates.len > 0:
      var best = candidates[0]
      var bestV = tagParts(best.name).pv
      for c in candidates[1..^1]:
        let cv = tagParts(c.name).pv
        if cmpVersion(cv, bestV) == 1:
          best = c
          bestV = cv
      return best
    return refs[0]

  # 5) branch match
  for h in heads:
    if h.name.endsWith("/" & version):
      return h

  # fallback
  return refs[0]


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
