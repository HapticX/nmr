import
  std/algorithm,
  std/terminal,
  std/strutils,
  std/json,
  std/os,
  ../utils


proc searchCommand*(help: bool = false, limit: int = 10, json: bool = false, toSearch: seq[string]) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "search ", fgRed, "<query>", fgWhite, " [options]\n"
    styledEcho "Search for packages in the registry.\n"
    styledEcho "Aliases:"
    styledEcho fgYellow, "  s \n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -j", fgWhite, ",", fgYellow, " --json", fgWhite, "    Output raw JSON\n"
    styledEcho fgYellow, "  -l", fgWhite, ",", fgYellow, " --limit", fgWhite, "   Max results (default: 10)\n"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, " --help", fgWhite, "    Show this help\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " search karax"
    return

  if not fileExists(packagesFile):
    styledEcho fgRed, "Error: ", fgWhite, "packages not found. Please try again later.\n"
    return
  
  var f = open(packagesFile, fmRead)
  let packages = parseJson(f.readAll())
  f.close()

  var searchFor: string = ""
  for i in toSearch:
    searchFor.add i.toLower()

  var results = newJArray()

  for package in packages:
    package["__s"] = %0
    for key in ["name", "description"]:
      if key notin package:
        continue
      let val = package[key].str.toLower()
      if searchFor in val:
        package["__s"].num += 1
    
    if "tags" in package:
      for tag in package["tags"]:
        let val = tag.str.toLower()
        if searchFor in val:
          package["__s"].num += 1
    
    if package["__s"].num > 0:
      results.add package
    
    if results.len >= limit:
      break
  
  results.elems = results.elems.sortedByIt(-it["__s"].num)

  let
    gridSize = ((terminalWidth() - 4 - 5 - 4 - 3) div 5) - 2
    name = gridSize
    desc = gridSize * 2
    url = gridSize * 3
  
  if json:
    echo results.pretty
  else:
    styledEcho "Found ", $results.len, " packages for ", fgYellow, "\"", toSearch.join(" "), "\":\n"
    styledEcho "NAME".alignLeft(name), " DESC".alignLeft(desc), "  URL".alignLeft(url)
    styledEcho "─".repeat(name+desc+url)
    for package in results:
      styledEcho(
        bgBlack,
        package["name"].str.alignLeft(name), " ",
        if "description" in package:
          highlight(package["description"].str, toSearch.join(" "), desc)
        else:
          "".alignLeft(desc),
        " ",
        if "url" in package:
          package["url"].str.alignLeft(url)
        else:
          "",
      )
