import
  std/terminal,
  std/strutils,
  std/macros,
  std/unicode,

  QRgen,
  QRgen/private/Drawing,

  ./ui


export
  ui


var
  useEmoji*: bool = true


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
    padding =
      case align
      of qraLeft: 0
      of qraCenter: (width - self.drawing.size.int) div 2
      of qraRight: (width - self.drawing.size.int)
  var result: string = newStringOfCap((size.uint16 * 2 + 11) * size + 10)
  stdout.setForegroundColor(clr)
  if not flush:
    result.add "\n"
  else:
    for y in countup(0, size.int, 2):
      stdout.cursorUp()
  for y in countup(0, size.int, 2):
    if not flush:
      result.add " ".repeat(padding)
    else:
      stdout.cursorDown()
      let (x, y) = getCursorPos()
      if x < padding:
        stdout.cursorForward(padding - x)
      elif x > padding:
        stdout.cursorBackward(x - padding)
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
        result.add ch
      else:
        stdout.write ch
    if flush:
      result.add "\n"
    else:
      stdout.write "\n"
  if flush:
    result.add "\n"
    stdout.write result
  stdout.resetAttributes()


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


