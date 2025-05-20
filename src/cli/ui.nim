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

