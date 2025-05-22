import
  std/strformat,
  std/strutils,
  std/terminal,
  std/macros,
  std/os,
  illwill


when defined(windows):
  {.passL: "-lkernel32".}
  proc GetConsoleOutputCP*(): cuint {.importc: "GetConsoleOutputCP", dynlib: "kernel32", stdcall.}
  const CP_UTF8* = 65001

  proc isUtf8CodePage*(): bool =
    GetConsoleOutputCP() == CP_UTF8

  proc isModernWindowsTerm*(): bool =
    getEnv("WT_SESSION").len > 0 or
    getEnv("TERM_PROGRAM").toLowerAscii() == "vscode"

else:
  # на Unix/macOS считается, что wcwidth >0 означает поддержку
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


var
  useEmoji*: bool = isEmojiSupported()
  packagesFile* = getDataDir() / "nmr" / "packages.json"


proc emoji*(e: string): string =
  if useEmoji:
    e
  else:
    ""


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
  while result.len == 0:
    stdout.styledWrite fgGreen, "?", fgCyan, fmt" {title} > ", fgBlack, bgWhite, defaultValue
    # return caret
    let (x, y) = getCursorPos()
    stdout.setCursorXPos(x - defaultValue.len)
    stdout.styledWrite fgWhite, bgBlack

    result = stdin.readLine()

    if result.len == 0:
      if defaultValue.len > 0:
        break
      stdout.cursorUp()
      stdout.setCursorXPos(0)
  
  if result.len == 0:
    result = defaultValue

  stdout.cursorUp()
  stdout.setCursorXPos(0)
  if defaultValue.len > result.len:
    styledEcho fgGreen, emoji"✔", fgCyan, fmt" {title} > ", fgGreen, result, " ".repeat(defaultValue.len - result.len)
  else:
    styledEcho fgGreen, emoji"✔", fgCyan, fmt" {title} > ", fgGreen, result


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
      stdout.styledWrite fgGreen, emoji"✔", fgCyan, fmt" {title} > ", fgGreen, opts[currentOpt], "\n"
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
