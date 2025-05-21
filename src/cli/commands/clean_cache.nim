import
  std/strutils,
  std/terminal,
  std/json,
  std/os,
  ../utils


proc cleanCacheCommand*(help: bool = false, skipNimble: bool = true, skipArchive: bool = true) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "clean-cache\n"
    styledEcho "Just cleans .cache/ directory.\n"
    styledEcho "Aliases:"
    styledEcho fgYellow, "  clnc ", fgWhite, "|", fgYellow, " cleancache\n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -sn", fgWhite, ",", fgYellow, " --skip-nimble", fgWhite, "    Skip *.nimble files"
    styledEcho fgYellow, "  -sa", fgWhite, ",", fgYellow, " --skip-archive", fgWhite, "   Skip *.zip archives"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, " --help", fgWhite, "            Show this help\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " clean-cache"
    styledEcho fgYellow, "  nmr", fgMagenta, " clnc ", fgBlue, "--skip-nimble"
    return
  
  if not dirExists(".cache") or not dirExists(".cache/nmr") or not dirExists(".cache/nmr/graph"):
    styledEcho fgYellow, "Warn: ", fgWhite, "Nothing to clean"
    return
  
  var i = 0

  for file in walkDirRec(".cache/nmr/graph"):
    let info = file.getFileInfo()
    if file.endsWith(".nimble") and not skipNimble:
      removeFile(file)
    elif file.endsWith(".zip") and not skipArchive:
      removeFile(file)
    
    if not fileExists(file):
      i += info.size
  
  if i == 0:
    styledEcho fgYellow, "Warn: ", fgWhite, "Nothing to clean"
  else:
    styledEcho fgGreen, "Success: ", fgWhite, "cleaned ", i.formatSize(includeSpace = true)
