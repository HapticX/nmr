import
  std/strformat,
  std/strutils,
  std/unicode,
  std/terminal,
  std/macros,
  std/os,
  illwill


when defined(windows):
  {.passL: "-lkernel32".}
  proc GetConsoleOutputCP*(): cuint {.importc: "GetConsoleOutputCP", dynlib: "kernel32", stdcall.}
  proc GetStdHandle*(nStdHandle: uint32): cuint {.importc: "GetStdHandle", dynlib: "kernel32", stdcall.}
  proc GetConsoleMode*(hConsoleHandle: cuint, lpMode: var uint32): bool {.importc: "GetConsoleMode", dynlib: "kernel32", stdcall.}
  proc SetConsoleMode*(hConsoleHandle: cuint, dwMode: uint32): bool {.importc: "SetConsoleMode", dynlib: "kernel32", stdcall.}

  {.passL: "-lmsvcrt".}
  proc getwch*(): cint {.importc: "_getwch", header: "<conio.h>".}

  const
    CP_UTF8* = 65001
    STD_OUTPUT_HANDLE* = uint32(-11)
    ENABLE_VIRTUAL_TERMINAL_PROCESSING* = uint32(0x0004)
  
  var ansiInited* = false
  var ansiEnabled* = false

  proc readKey*(): int =
    let wc = getwch()
    return wc.int

  proc isUtf8CodePage*(): bool =
    GetConsoleOutputCP() == CP_UTF8

  proc isModernWindowsTerm*(): bool =
    getEnv("WT_SESSION").len > 0 or
    getEnv("TERM_PROGRAM").toLowerAscii() == "vscode"
  
  proc initAnsi*() =
    if not ansiInited:
      ansiInited = true
      let h = GetStdHandle(STD_OUTPUT_HANDLE)
      var mode: uint32
      if GetConsoleMode(h, mode):
        if (mode and ENABLE_VIRTUAL_TERMINAL_PROCESSING) == 0:
          if SetConsoleMode(h, mode or ENABLE_VIRTUAL_TERMINAL_PROCESSING):
            ansiEnabled = true
        else:
          ansiEnabled = true

else:
  import posix, termios

  proc wcwidth*(wc: wchar_t): cint {.importc: "wcwidth", header: "<wchar.h>".}

  proc isUtf8Locale*(): bool =
    for envName in @["LC_ALL", "LC_CTYPE", "LANG"]:
      let v = getEnv(envName)
      if v.len > 0 and v.toLowerAscii().contains("utf-8"):
        return true
    return false

  proc isEmojiSupportedUnix*(): bool =
    if not stdout.isatty:
      return false
    if not isUtf8Locale():
      return false
    let sample: Rune = cast[Rune](0x1F680)
    wcwidth(cast[wchar_t](sample)) > 0

  proc rawReadByte*(): int =
    var buf: array[1, uint8] = [0'u8]
    let n = read(stdin.fileno(), addr buf, 1)
    if n <= 0: return -1
    return buf[0].int

  proc readKey*(): int =
    var oldt, newt: termios.Termios
    let fd = stdin.fileno()
    if tcgetattr(fd, oldt) != 0: return 0
    newt = oldt
    newt.c_lflag = oldt.c_lflag and not (Posix.ICANON or Posix.ECHO)
    if tcsetattr(fd, Posix.TCSANOW, newt) != 0:
      discard tcsetattr(fd, Posix.TCSANOW, oldt)
      return 0

    let first = rawReadByte()
    discard tcsetattr(fd, Posix.TCSANOW, oldt)
    if first < 0: return 0

    if (first and 0x80) == 0:
      return first

    var seqLen = 0
    if (first and 0xE0) == 0xC0: seqLen = 1
    elif (first and 0xF0) == 0xE0: seqLen = 2
    elif (first and 0xF8) == 0xF0: seqLen = 3
    elif (first and 0xFC) == 0xF8: seqLen = 4
    else:
      return first

    var codepoint = first and (0x7F shr seqLen)
    for _ in 1..seqLen:
      let b = rawReadByte()
      if (b and 0xC0) != 0x80:
        break
      codepoint = (codepoint shl 6) or (b and 0x3F)
    return codepoint


proc isEmojiSupported*(): bool =
  if not stdout.isatty: return false

  when defined(windows):
    if not isUtf8CodePage():
      return false
    if not isModernWindowsTerm():
      return false
    return true
  else:
    return isEmojiSupportedUnix()


proc colored*(text: string, r, g, b: int): string =
  if not stdout.isatty:
    return text
  when defined(windows):
    initAnsi()
    if not ansiEnabled:
      return text
  else:
    let term = getEnv("TERM")
    if term.len == 0 or term.toLowerAscii() == "dumb":
      return text

  let esc   = "\x1b[38;2;" & $r & ";" & $g & ";" & $b & "m"
  let reset = "\x1b[0m"
  return esc & text & reset


var
  useEmoji*: bool = isEmojiSupported()
  packagesFile* = getDataDir() / "nmr" / "packages.json"


proc emoji*(e: string): string =
  if useEmoji: e else: ""

proc emoji1*(e: string): string =
  if useEmoji: e else: " "


macro countPadding*(args: varargs[typed]): untyped =
  var count = 0
  for item in args:
    case item.kind
    of nnkStrLit..nnkTripleStrLit:
      count += item.strVal.len
    else:
      discard
  return newLit(count)


template centeredEcho*(args: varargs[untyped]) =
  block:
    let width = terminalWidth()
    let padding = (width - countPadding(args)) div 2
    styledWrite(stdout, " ".repeat(padding), args)
    write(stdout, "\n")


template rightEcho*(args: varargs[untyped]) =
  block:
    let width = terminalWidth()
    let padding = (width - countPadding(args))
    styledWrite(stdout, " ".repeat(padding), args)
    write(stdout, "\n")


func crop*(s: string, length: int): string =
  if s.len > length:
    s[0..length-4] & "..."
  else:
    s


proc highlight*(a, b: string, length: int, clr: terminal.ForegroundColor = fgGreen): string =
  var
    i = a.toLower().find(b.toLower())
    src = a
    dst = b

  if i == -1:
    i = b.toLower().find(a.toLower())
    src = b
    dst = a
  
  if i > 0:
    result = "..."
    if src.len - i+3 > length:
      result &= src[i..i+dst.len-1] & src[i+dst.len..i-4+length-3] & "..."
    else:
      result &= src[i..i+dst.len-1] & src[i+dst.len..^1]
    result = result.alignLeft(length)
  elif i == 0:
    if src.len - i+3 > length:
      result &= src[i..i+dst.len-1] & src[i+dst.len..i+length-3] & "..."
    else:
      result &= src[i..i+dst.len-1] & src[i+dst.len..^1]
    result = result.alignLeft(length)
  else:
    result = crop(dst, length).alignLeft(length)


proc enterValue*(
    title: string,
    defaultValue: string = ""
): string =
  result = ""
  var input: seq[Rune]
  while input.len == 0:
    stdout.styledWrite fgGreen, "?", fgCyan, fmt" {title} > ", colored(defaultValue, 100, 100, 100)
    # return caret
    let (x, y) = getCursorPos()
    let valueX = x - defaultValue.len
    stdout.setCursorXPos(valueX)
    stdout.styledWrite fgWhite, bgBlack

    while true:
      let key = readKey()
      if key == 13:  # Enter
        break
      elif key == 3 or key == 7:  # Ctrl-C or Esc
        quit(QuitSuccess)
      elif key == 8:  # Backspace
        stdout.cursorBackward()
        stdout.write " "
        if input.len > 0:
          input = input[0..^2]
      elif key > 0:
        input &= cast[Rune](key)
      
      if input.len == 0:
        stdout.setCursorXPos(0)
        stdout.styledWrite fgGreen, "?", fgCyan, fmt" {title} > ", colored(defaultValue, 100, 100, 100)
      else:
        stdout.setCursorXPos(0)
        stdout.styledWrite fgGreen, "?", fgCyan, fmt" {title} > ", colored($input, 255, 255, 255), " ".repeat(defaultValue.len)
      let (x, y) = getCursorPos()
      stdout.setCursorXPos(x - defaultValue.len)
      stdout.styledWrite fgWhite, bgBlack
      sleep(20)

    if result.len == 0:
      if defaultValue.len > 0:
        break
      stdout.setCursorXPos(0)
  
  if input.len == 0:
    result = defaultValue
  else:
    result = $input

  stdout.setCursorXPos(0)
  if defaultValue.len > result.len:
    styledEcho fgGreen, emoji1"✔", fgCyan, fmt" {title} > ", fgGreen, result, bgBlack, " ".repeat(defaultValue.len)
  else:
    styledEcho fgGreen, emoji1"✔", fgCyan, fmt" {title} > ", fgGreen, result


proc chooseOption*(
  title: string,
  options: seq[string],
  defaultOption: string,
): string =
  var opts = options
  if defaultOption notin options and defaultOption.len > 0:
    opts.add defaultOption
  
  stdout.styledWrite fgGreen, "?", fgCyan, fmt" {title}:", "\n"

  var currentOpt = 0

  for i in 0..<opts.len:
    if (defaultOption.len > 0 and opts[i] == defaultOption) or (defaultOption.len == 0 and i == 0):
      stdout.styledWrite fgCyan, " > ", opts[i], "\n"
      result = opts[i]
      currentOpt = i
    else:
      stdout.styledWrite fgWhite, "   ", opts[i], "\n"

  while true:
    let key = getKey()
    case key
    of Key.Enter:
      for i in countdown(opts.len-1, 0):
        stdout.cursorUp()
        stdout.setCursorXPos(0)
        stdout.styledWrite fgWhite, "   ", " ".repeat(opts[i].len)
      stdout.setCursorXPos(0)
      stdout.cursorUp()
      result = opts[currentOpt]
      stdout.styledWrite fgGreen, emoji1"✔", fgCyan, fmt" {title} > ", fgGreen, opts[currentOpt], "\n"
      break
    of Key.Up, Key.Down, Key.Tab:
      if key == Key.Up:
        if currentOpt > 0:
          dec currentOpt
        else:
          currentOpt = opts.len-1
      else:
        if currentOpt < opts.len-1:
          inc currentOpt
        else:
          currentOpt = 0
      for i in 0..<opts.len:
        stdout.cursorUp()
      for i in 0..<opts.len:
        stdout.setCursorXPos(0)
        if i == currentOpt:
          stdout.styledWrite fgCyan, " > ", opts[i], "\n"
        else:
          stdout.styledWrite fgWhite, "   ", opts[i], "\n"
    else:
      discard
    sleep(20)
