import
  std/asyncdispatch,
  std/httpclient,
  std/strutils,
  std/strscans


proc getRefs*(repo: string, tags: bool = true, heads: bool = true, pulls: bool = true): Future[seq[tuple[hash, name: string]]] {.async.} =
  let httpClient = newAsyncHttpClient()
  var
    res: seq[tuple[hash, name: string]] = @[]
    url = repo
  url.removeSuffix("/")
  url.removeSuffix(".git")
  let response = await httpClient.get(url & ".git/info/refs?service=git-upload-pack")
  if response.code == Http200:
    let output = await response.body()
    for i in output.splitLines:
      var hash, name: string
      if i.scanf("$+ $+", hash, name):
        if name == "service=git-upload-pack":
          continue
        if not tags and name.startsWith("refs/tags/"):
          continue
        if not heads and (name.startsWith("refs/heads/") or name.startsWith("HEAD")):
          continue
        if not pulls and name.startsWith("refs/pull/"):
          continue
        res.add((hash: hash, name: name.split('\x00')[0]))
  return res
