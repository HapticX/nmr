import
  std/strutils


proc parseVersion*(v: string): seq[int] =
  var s = v.strip()
  if s.startsWith("refs/tags/"):
    s = s.split('/')[^1]
  var tmpS = s
  s = ""
  for i in tmpS:
    if i in {'0'..'9', '.'}:
      s &= i
  # strip leading "v"
  if s.startsWith("v"):
    s = s[1 .. ^1]
  let parts = s.split('.')
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

proc tagParts(tn: string): tuple[rf: string, pv: seq[int]] =
  let name = if tn.startsWith("refs/tags/"): tn.split('/')[^1] else: tn
  (tn, parseVersion(name))


proc findTag*(refs: seq[tuple[hash, name: string]], op, version: string): tuple[hash, name: string] =
  ## Select a git ref (tag or head) from `refs` according to `op` and `version`.
  ## If both `op` and `version` are empty, pick the highest‐semver tag.

  # split into tags and heads
  var tags, heads: seq[tuple[hash, name: string]]
  for r in refs:
    if r.name.startsWith("refs/tags/"): tags.add r
    elif r.name.startsWith("refs/heads/"): heads.add r

  # 1) no op & no version: pick highest semver tag
  if op.len == 0 and version.len == 0:
    if tags.len > 0:
      # find max by semver
      var best = tags[0]
      var bestV = tagParts(best.name).pv
      for t in tags[1..^1]:
        let (_, tv) = tagParts(t.name)
        if cmpVersion(tv, bestV) == 1:
          best = t
          bestV = tv
      return best
    else:
      return refs[0]

  # 2) HEAD shortcut
  if version[0] == '#' and version[1..^1].toLowerAscii().strip() == "head":
    return refs[0]
  elif version.toLowerAscii().strip() == "head":
    return refs[0]

  # 3) direct "#hash" syntax
  let libhash = version.split("#")
  if libhash.len == 2:
    return (hash: "", name: libhash[1])

  # 4) semver operator on tags
  if op.len > 0 and version.len > 0:
    let pv = parseVersion(version)
    var candidates: seq[tuple[hash, name: string]]

    case op
    of ">":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) == 1: candidates.add t
    of "<":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) == -1: candidates.add t
    of ">=":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) >= 0: candidates.add t
    of "<=":
      for t in tags:
        if cmpVersion(tagParts(t.name).pv, pv) <= 0: candidates.add t
    of "~=":
      var bump = pv
      if bump.len >= 2: bump[1] += 1 else: bump[0] += 1
      for t in tags:
        let tv = tagParts(t.name).pv
        if cmpVersion(tv, pv) >= 0 and cmpVersion(tv, bump) < 0:
          candidates.add t
    of "^=":
      var bound: seq[int]
      if pv.len >= 1 and pv[0] != 0:
        bound = @[pv[0] + 1]
      elif pv.len >= 2 and pv[1] != 0:
        bound = @[0, pv[1] + 1]
      elif pv.len >= 3:
        bound = @[0, 0, pv[2] + 1]
      else:
        bound = @[pv[0] + 1]
      for t in tags:
        let tv = tagParts(t.name).pv
        if cmpVersion(tv, pv) >= 0 and cmpVersion(tv, bound) < 0:
          candidates.add t
    of "==":
      let want = parseVersion(version).join(".")
      for t in tags:
        let nm = if t.name.startsWith("refs/tags/"): t.name.split('/')[^1] else: t.name
        if nm == want:
          return t
    else:
      discard

    if candidates.len > 0:
      var best = candidates[0]
      var bestV = tagParts(best.name).pv
      for c in candidates[1..^1]:
        let cv = tagParts(c.name).pv
        if cmpVersion(cv, bestV) == 1:
          best = c
          bestV = cv
      return best
    return refs[0]

  # 5) branch match
  for h in heads:
    if h.name.endsWith("/" & version):
      return h

  # fallback
  return refs[0]
