import std/[strscans, strutils, sequtils]

type
  ConstraintKind* = enum
    ckGt, ckGte, ckLt, ckLte, ckEq

  Constraint* = object
    kind*: ConstraintKind
    ver*: seq[int]    # [major, minor, patch]

proc parseVersion*(v: string): seq[int] =
  var s = v.strip()
  if s.startsWith("refs/tags/"):
    s = s.split("/")[^1]
  if s.startsWith("v"):
    s = s[1..^1]
  var clean = newStringOfCap(s.len)
  for c in s:
    if c.isDigit or c == '.':
      clean.add c
  let parts = clean.split('.').filterIt(it.len > 0)
  if parts.len == 0:
    return @[0]
  result.setLen(parts.len)
  for i, p in parts:
    result[i] = p.parseInt()

proc cmpVersion*(a, b: seq[int]): int =
  let n = max(a.len, b.len)
  for i in 0..<n:
    let ai = if i < a.len: a[i] else: 0
    let bi = if i < b.len: b[i] else: 0
    if ai < bi: return -1
    if ai > bi: return 1
  return 0

proc toVerSeq*(vstr: string): seq[int] =
  var v = parseVersion(vstr)
  while v.len < 3: v.add 0
  if v.len > 3: v.setLen 3
  result = v

proc parseRange*(rangeStr: string): seq[seq[Constraint]] =
  result = @[]
  for orPart in rangeStr.split("||"):
    let p0 = orPart.strip()
    if p0.len == 0: continue
    var constraints: seq[Constraint] = @[]

    let rangeData = p0.split("-")
    if rangeData.len == 2:
      let
        low = rangeData[0].strip()
        high = rangeData[1].strip()
      constraints.add Constraint(kind: ckGte, ver: toVerSeq(low))
      constraints.add Constraint(kind: ckLte, ver: toVerSeq(high))
    else:
      var toks = p0.replace("&", " ").replace("  ", " ").split(' ').filterIt(it.len > 0)
      var idx = 0
      while idx < toks.len:
        let t = toks[idx].strip()
        var opStr, verstr: string

        if t in @["<", ">", "<=", ">=", "==", "~=", "^="]:
          opStr = t
          if idx+1 < toks.len:
            verstr = toks[idx+1].strip()
            inc idx
          else:
            break
        else:
          # combined operator+version or plain version
          if t.startsWith(">="):
            opStr = ">="; verstr = t.substr(2)
          elif t.startsWith("<="):
            opStr = "<="; verstr = t.substr(2)
          elif t.startsWith("^="):
            opStr = "^="; verstr = t.substr(2)
          elif t.startsWith("~="):
            opStr = "~="; verstr = t.substr(2)
          elif t.startsWith(">"):
            opStr = ">";  verstr = t.substr(1)
          elif t.startsWith("<"):
            opStr = "<";  verstr = t.substr(1)
          elif t.startsWith("=="):
            opStr = "=="; verstr = t.substr(2)
          else:
            opStr = "=="; verstr = t
        # wildcard?
        if verstr.find('x') >= 0 or verstr.find('*') >= 0:
          let comps = verstr.split('.')
          var lower: seq[int] = @[]
          for c in comps:
            if c.toLowerAscii() in @["x","*"]: lower.add 0
            else: lower.add c.parseInt()
          while lower.len < 3: lower.add 0
          var upper: seq[int] = if lower.len > 0: lower[0..^1] else: @[]
          for i2, c in comps:
            if c.toLowerAscii() in @["x","*"] and i2 < upper.len:
              upper[i2] = upper[i2] + 1
              for j in (i2+1)..<upper.len: upper[j] = 0
              break
          constraints.add Constraint(kind: ckGte, ver: lower)
          constraints.add Constraint(kind: ckLt,  ver: upper)
        else:
          let vseq = toVerSeq(verstr)
          case opStr
          of ">":  constraints.add Constraint(kind: ckGt,  ver: vseq)
          of ">=": constraints.add Constraint(kind: ckGte, ver: vseq)
          of "<":  constraints.add Constraint(kind: ckLt,  ver: vseq)
          of "<=": constraints.add Constraint(kind: ckLte, ver: vseq)
          of "==": constraints.add Constraint(kind: ckEq,  ver: vseq)
          of "~=":
            var bump = if vseq.len > 0: vseq[0..^1] else: @[]
            bump[1] = bump[1] + 1
            constraints.add Constraint(kind: ckGte, ver: vseq)
            constraints.add Constraint(kind: ckLt,  ver: bump)
          of "^=":
            var bound: seq[int]
            if vseq[0] != 0:
              bound = @[vseq[0]+1, 0,0]
            elif vseq[1] != 0:
              bound = @[0, vseq[1]+1, 0]
            else:
              bound = @[0,0, vseq[2]+1]
            constraints.add Constraint(kind: ckGte, ver: vseq)
            constraints.add Constraint(kind: ckLt,  ver: bound)
          else:
            discard
        inc idx
    result.add constraints
  return

proc satisfies*(v: seq[int], cons: seq[Constraint]): bool =
  for c in cons:
    let cmp = cmpVersion(v, c.ver)
    case c.kind
    of ckGt:
      if cmp <= 0: return false
    of ckGte:
      if cmp <  0: return false
    of ckLt:
      if cmp >= 0: return false
    of ckLte:
      if cmp >  0: return false
    of ckEq:
      if cmp != 0: return false
  return true

proc latestTag*(refs: seq[tuple[hash, name: string]]): tuple[hash, name: string] =
  let tags = refs.filterIt(it.name.startsWith("refs/tags/"))
  if tags.len > 0:
    result = tags[0]
    var bestV = toVerSeq(result.name)
    for t in tags[1..^1]:
      let tv = toVerSeq(t.name)
      if cmpVersion(tv, bestV) == 1:
        result = t; bestV = tv
  else:
    result = refs[0]

proc findTag*(refs: seq[tuple[hash, name: string]], version: string): tuple[hash, name: string] =
  let ver = version.strip()
  if ver.len == 0:
    return refs.latestTag()

  if ver.contains('#'):
    let parts = ver.split('#', 1)
    let suffix = parts[1].strip()
    let tail   = if suffix.contains(' '): suffix.split(' ', 1)[1] else: ""
    if suffix.startsWith("head"):
      if tail.len > 0:
        # semver tail after head
        let ranges = parseRange(tail)
        var cands: seq[tuple[hash, name: string]] = @[]
        for r in refs:
          if r.name.startsWith("refs/tags/"):
            let vseq = toVerSeq(r.name)
            if ranges.anyIt(vseq.satisfies(it)):
              cands.add r
        if cands.len > 0:
          return cands.latestTag()
      return refs[0]
    else:
      return (hash: "", name: suffix)
  
  let ranges = parseRange(ver)
  var cands: seq[tuple[hash, name: string]] = @[]
  for r in refs:
    if r.name.startsWith("refs/tags/"):
      let vseq = toVerSeq(r.name)
      if ranges.anyIt(vseq.satisfies(it)):
        cands.add r
  if cands.len > 0:
    return cands.latestTag()
  for r in refs:
    if r.name.startsWith("refs/heads/") and r.name.endsWith("/" & ver):
      return r
  return refs[0]
