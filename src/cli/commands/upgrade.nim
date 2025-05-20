import
  std/terminal,
  ../utils


proc upgradeCommand*(help: bool) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "upgrade\n"

    styledEcho "Fetches latest version of Nim packages"
    styledEcho fgYellow, "https://github.com/nim-lang/packages"
  else:
    fetchPackages()
