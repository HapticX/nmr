import
  compiler / [ast, idents, msgs, syntaxes, options, pathutils, lineinfos],
  std/strscans,
  std/strformat,
  std/strutils,
  std/terminal,
  std/os,
  ./types


proc parseNimble(node: PNode, dep: Dependency, featureList: seq[string] = @[])


proc vop*(input: string; strVal: var string; start: int): int =
  # matches exactly ``n`` digits. Matchers need to return 0 if nothing
  # matched or otherwise the number of processed chars.
  if start+1 < input.len and input[start..start+1] in [">=", "<=", "~=", "==", "^="]:
    result = 2
    strVal = input[start..start+1]
  elif start < input.len and input[start] in {'<', '>', '@'}:
    result = 1
    strVal = $input[start]


proc pkgName*(input: string; strVal: var string; start: int): int =
  ## Match a package spec starting at `start`. Recognizes:
  ##  - plain names (e.g. jester), stopping before "#" if it's a version
  ##  - git URLs (with "://"), keeping any "#" in the URL
  ##  - stops at whitespace or before a version‐operator (vop)
  ##
  ## Returns length consumed, or 0 if no match.

  strVal = ""
  if start < 0 or start >= input.len:
    return 0

  var i = start
  while i < input.len:
    let c = input[i]
    # stop on whitespace
    if c in Whitespace:
      break

    # stop on version-operator
    var op = ""
    if vop(input, op, i) > 0:
      break

    # stop on '#' only if this isn't a URL
    if c == '#':
      let prefix = input[start ..< i]
      if not prefix.contains("://"):
        break
    inc(i)

  if i <= start:
    return 0

  strVal = input[start ..< i]
  result = i


proc definedName(node: PNode): string =
  if node.kind == nkCall and node[0].kind == nkIdent and node[0].ident.s == "defined":
    result = node[1].ident.s


proc evalWhen(argument: string): bool =
  case argument
  of "windows":
    when defined(windows): true else: false
  of "linux":
    when defined(linux): true else: false
  of "posix":
    when defined(posix): true else: false
  of "macosx":
    when defined(macosx): true else: false
  else: false


proc parseWhenElifBranch(node: PNode, dep: Dependency, featureList: seq[string] = @[]): bool =
  if node.kind == nkElifBranch:
    let (cond, body) = (node[0], node[1])
    if cond.kind == nkPrefix and cond[0].kind == nkIdent and cond[0].ident.s == "not":
      let name = definedName cond[1]
      if name.len > 0:
        if not evalWhen(name):
          parseNimble(body, dep, featureList)
          return true
    elif definedName(cond).len > 0:
      if evalWhen(definedName(cond)):
        parseNimble(body, dep, featureList)
        return true
    elif cond.kind == nkInfix and cond[0].kind == nkIdent and cond[0].ident.s == "or":
      let (right, left) = (definedName(cond[1]), definedName(cond[2]))
      if left.len > 0 or right.len > 0:
        if evalWhen(left) or evalWhen(right):
          parseNimble(body, dep, featureList)
          return true


proc parseNimble(node: PNode, dep: Dependency, featureList: seq[string] = @[]) =
  case node.kind
  of nkStmtList, nkStmtListExpr:
    for n in node:
      parseNimble(n, dep, featureList)
  of nkCallKinds:
    if node[0].kind == nkIdent:
      case node[0].ident.s
      of "requires":
        for i in 1..<node.len:
          var ch = node[i]
          while ch.kind in { nkStmtListExpr, nkStmtList } and ch.len > 0:
            ch = ch.lastSon
          if ch.kind in nkStrKinds:
            var
              pkg, version: string
            if ch.strVal.scanf("${pkgName}$*", pkg, version): discard
            if pkg.len > 0 and pkg.toLower() != "nim":
              dep.children.add Dependency(parent: dep, children: @[], name: pkg, version: version)
      of "task":
        if node.len >= 3 and node[1].kind == nkIdent and node[2].kind in nkStrKinds:
          dep.tasks.add (command: node[1].ident.s, name: node[2].strVal)
      of "feature":
        if node.len >= 2 and node[1].kind in nkStrKinds:
          dep.features.add node[1].strVal
      else:
        discard
  of nkAsgn, nkFastAsgn:
    if node[0].kind == nkIdent and node[1].kind in nkStrKinds:
      case node[0].ident.s
      of "srcDir":
        dep.srcDir = node[1].strVal
      of "version":
        dep.version = node[1].strVal
      else:
        discard
  of nkWhenStmt:
    var wasParsed = false
    for branch in node:
      if parseWhenElifBranch(branch, dep):
        wasParsed = true
        break
    if not wasParsed and node[^1].kind == nkElse:
      parseNimble(node[^1][0], dep, featureList)
  else:
    discard


proc parseNimbleFile*(filename: string, featureList: seq[string] = @[]): Dependency =
  if not fileExists(filename):
    return nil

  let (dir, name, ext) = filename.splitFile()
  var
    tmp = ""
    version = ""
    srcDir = ""
    f = open(filename, fmRead)
  let data = f.readAll()
  f.close()

  result = Dependency(children: @[], name: name, version: version, parent: nil)
  
  var conf = newConfigRef()
  conf.foreignPackageNotes = {}
  conf.notes = {}
  conf.mainPackageNotes = {}
  var parser: Parser
  let fileIdx = fileInfoIdx(conf, AbsoluteFile filename)
  if setupParser(parser, fileIdx, newIdentCache(), conf):
    let parsed = parseAll(parser)
    parseNimble(parsed, result, featureList)
