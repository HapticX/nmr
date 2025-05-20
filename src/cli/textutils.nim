import
  std/terminal,
  std/strutils,
  std/macros


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


proc highlight*(a, b: string, length: int, clr: ForegroundColor = fgGreen): string =
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
