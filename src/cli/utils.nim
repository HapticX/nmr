import
  std/asyncdispatch,
  std/asyncfile,
  std/httpclient,
  std/terminal,
  std/strutils,
  std/strscans,
  std/unicode,
  std/macros,
  std/osproc,
  std/json,
  std/os,

  zippy/ziparchives,
  taskpools,
  QRgen/private/Drawing,
  QRgen,

  ./textutils,
  ./types


export
  textutils,
  types


var
  useEmoji*: bool = true
  packagesFile* = getDataDir() / "nmr" / "packages.json"


const PACKAGES = "https://raw.githubusercontent.com/nim-lang/packages/refs/heads/master/packages.json"


proc emoji*(e: string): string =
  if useEmoji:
    e
  else:
    ""


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
  let
    nmrFolder = getDataDir() / "nmr"
    globalPackages = getDataDir() / "nmr" / "pkgs"
  if not dirExists(nmrFolder):
    createDir(nmrFolder)
  if not dirExists(globalPackages):
    createDir(globalPackages)
  
  if not fileExists(packagesFile):
    fetchPackages()


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


proc vop(input: string; strVal: var string; start: int): int =
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
    f = open(filename, fmRead)
  let data = f.readAll()
  f.close()

  if data.scanf("$*version$s=$s\"$*\"", tmp, version):
    discard
  
  result = Dependency(children: @[], name: name, version: version, parent: nil)

  for i in data.split("\n"):
    var
      pkg, op, version: string
    if i.scanf("$srequires$s\"$w$s${vop}$s$*\"", pkg, op, version):
      discard
    elif i.scanf("$srequires$s\"$w\"", pkg):
      op = ""
      version = ""
    if pkg.len > 0 and version.len > 0 and pkg.toLower() != "nim":
      result.children.add Dependency(parent: result, children: @[], name: pkg, version: op & " " & version)


proc getBranches*(repo: string, args: seq[string] = @["--heads"]): seq[tuple[hash, name: string]] =
  result = @[]
  let (output, exitCode) = execCmdEx("git ls-remote " & args.join(" ") & " " & repo)
  for i in output.split("\n"):
    var hash, name: string
    if i.scanf("$w$s$+", hash, name):
      result.add((hash: hash, name: name))


proc findPackage*(name: string, packages: JsonNode): JsonNode =
  var pkg: JsonNode
  for package in packages:
    if "name" in package and name.toLower() == package["name"].str.toLower():
      pkg = package
      if "alias" in pkg:
        pkg = findPackage(pkg["alias"].str, packages)
      break
  pkg


proc processDep*(dep: Dependency, packages: JsonNode) {.async.} =
  try:
    if not dirExists(".cache"): createDir(".cache")
    if not dirExists(".cache/nmr"): createDir(".cache/nmr")
    if not dirExists(".cache/nmr/graph"): createDir(".cache/nmr/graph")

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
        let
          url = "https://raw.githubusercontent.com/" & ghPath & "/HEAD/" & pkg["name"].str & ".nimble"
          filename = ".cache/nmr/graph/" & dep.name & ".nimble"
        var data = await client.get(url)
        if data.code == Http200:
          var f = openAsync(filename, fmWrite)
          await f.write(await data.body)
          f.close()
        else:
          let
            urlZip = "https://github.com/" & ghPath & "/archive/HEAD/" & pkg["name"].str & ".zip"
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
              var f = openAsync(filename, fmWrite)
              await f.write(reader.extractFile(archiveFile))
              f.close()
          finally:
            reader.close()
          removeFile(filenameZip)
        
        var currentDep = parseNimbleFile(filename)
        if currentDep.isNil:
          return
        
        var childFuts: seq[Future[void]] = @[]
        for nextDep in currentDep.children:
          childFuts.add processDep(nextDep, packages)
          dep[].children.add nextDep
        await gather(childFuts)
  except:
    echo getCurrentExceptionMsg()


proc depsGraph*(filename: string): Future[Dependency] {.async.} =
  var f = openAsync(packagesFile, fmRead)
  let packages = parseJson(await f.readAll())
  f.close()
  
  result = parseNimbleFile(filename)

  if result.isNil:
    return result

  var rootFuts: seq[Future[void]] = @[]
  for dep in result.children:
    rootFuts.add processDep(dep, packages)
  await gather(rootFuts)
