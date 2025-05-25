import
  std/strformat,
  std/strutils,
  std/tables


type
  Dependency* = ref object
    parent*: Dependency
    children*: seq[Dependency]
    name*, version*: string
    srcDir*: string
    url*: string
    gitRef*: tuple[hash, name: string]
    tasks*: seq[tuple[command, name: string]]
    features*: seq[string]
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


proc toInstallOrder*(root: Dependency): seq[Dependency] =
  var
    res: seq[Dependency] = @[]
    visited: seq[Dependency] = @[]

  proc visit(d: Dependency) =
    if d in visited: return
    visited.add(d)
    for child in d.children:
      visit(child)
    res.add(d)

  visit(root)
  return res


proc `$`*(dep: Dependency): string =
  var seen = initTable[string, bool]()
  pretty(dep, seen = seen)
