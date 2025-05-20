import
  std/strutils

type
  Dependency* = ref object
    parent*: Dependency
    children*: seq[Dependency]
    name*, version*: string
  QrAlign* = enum
    qraLeft,
    qraCenter,
    qraRight


proc pretty*(dep: Dependency, prefix: string = "", isLast: bool = true): string =
  var res = newStringOfCap(128)

  if prefix.len > 0:
    let branch = if isLast: "└─ " else: "├─ "
    res.add prefix & branch & dep.name & " " & dep.version & "\n"
  else:
    res.add dep.name & " " & dep.version & "\n"

  let childPrefix = prefix & (if isLast: "   " else: "│  ")

  for i, child in dep.children:
    let lastChild = i == dep.children.len - 1
    res.add pretty(child, childPrefix, lastChild)

  return res


proc `$`*(dep: Dependency): string = pretty(dep)
