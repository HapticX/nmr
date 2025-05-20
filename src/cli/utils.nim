import
  std/terminal,
  std/strutils,
  std/macros,
  std/unicode,
  std/httpclient,
  std/os,
  std/cpuinfo,

  taskpools,
  QRgen,
  QRgen/private/Drawing,

  ./ui


export
  ui


var
  useEmoji*: bool = true


const PACKAGES = "https://raw.githubusercontent.com/nim-lang/packages/refs/heads/master/packages.json"


proc emoji*(e: string): string =
  if useEmoji:
    e
  else:
    ""


type
  QrAlign* = enum
    qraLeft,
    qraCenter,
    qraRight,


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


proc waitAndProgress[T](action: string, fv: Flowvar[T], color: ForegroundColor = fgCyan) =
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


proc fetchPackages*() =
  var tp = Taskpool.new(countProcessors())
  var x = tp.spawn downloadParallel(getDataDir() / "nmr" / "packages.json")
  waitAndProgress("Fetching packages", x)
  styledEcho fgCyan, "[Fetching packages]", fgGreen, " Completed"


proc initCli*() =
  let
    nmrFolder = getDataDir() / "nmr"
    globalPackages = getDataDir() / "nmr" / "pkgs"
    packagesFile = getDataDir() / "nmr" / "packages.json"
  if not dirExists(nmrFolder):
    createDir(nmrFolder)
  if not dirExists(globalPackages):
    createDir(globalPackages)
  
  if not fileExists(packagesFile):
    fetchPackages()


# proc printTinyQRCode*(self: DrawedQRCode, clr: ForegroundColor = fgYellow) =
#   ## QR → Braille, корректная нумерация точек + quiet zone + защита от выхода за границы
#   let
#     origSize = self.drawing.size.int
#     qz       = 4                            # quiet zone в модулях
#     size     = origSize + 2*qz
#     width    = terminalWidth()
#     outW     = (size + 1) div 2            # символов по горизонтали
#     pad      = max(0, (width - outW) div 2)
#     base     = 0x2800                       # U+2800

#   # 1) строим расширенную матрицу с quiet zone
#   var mat = newSeq[seq[bool]](size)
#   for y in 0..<size:
#     mat[y] = newSeq[bool](size)
#   for y in 0..<origSize:
#     for x in 0..<origSize:
#       if self.drawing[x.uint8, y.uint8]:
#         mat[y+qz][x+qz] = true

#   # 2) вспомогательная таблица: dy,dx → вес бита в Braille
#   let bitIndex = [[0, 3], [1, 4], [2, 5], [6, 7]]

#   # 3) печатаем по блокам 2×4 → один Braille-символ
#   stdout.setForegroundColor(clr)
#   for y in countup(0, size-1, 4):
#     stdout.write " ".repeat(pad)
#     for x in countup(0, size-1, 2):
#       var mask = 0
#       for dy in 0..<4:
#         for dx in 0..<2:
#           let yy = y + dy
#           let xx = x + dx
#           # проверяем, что не вышли за границы
#           if yy < size and xx < size and mat[yy][xx]:
#             mask = mask or (1 shl bitIndex[dy][dx])
#       stdout.write $(cast[Rune](base + mask))
#     stdout.write "\n"
#   stdout.resetAttributes()


