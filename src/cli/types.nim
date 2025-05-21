import
  std/strformat,
  std/strutils,
  std/tables


type
  Dependency* = ref object
    parent*: Dependency
    children*: seq[Dependency]
    name*, version*: string
  QrAlign* = enum
    qraLeft,
    qraCenter,
    qraRight


proc pretty*(
    dep: Dependency,
    prefix: string = "",
    isLast: bool = true,
    seen: var Table[string, bool]
): string =
  result = newStringOfCap(128)
  let
    key = fmt"{dep.name} {dep.version}"
    branch = if prefix.len > 0:
               if isLast: "└─ " else: "├─ "
             else: ""
  result.add prefix & branch & key & "\n"
  if not seen.hasKey(key):
    seen[key] = true
    let childPrefix = prefix & (if isLast: "   " else: "│  ")
    for i, child in dep.children:
      let lastChild = i == dep.children.len - 1
      result.add pretty(child, childPrefix, lastChild, seen)


proc `$`*(dep: Dependency): string =
  var seen = initTable[string, bool]()
  pretty(dep, seen = seen)
