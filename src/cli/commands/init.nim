import
  std/strformat,
  std/strutils,
  std/terminal,
  std/unicode,
  std/os,
  illwill,
  ../utils


const
  gitignoreTemplate = """# Builds
*.exe
*.js

# Logs
*.log
*.lg

# Cache
.cache/
deps/
nim_deps/
"""
  nimbleTemplate = """# Package
verion = "{pkgVersion}"
author = "{pkgAuthor}"
description = "{pkgDescription}"
license = "{pkgLicense}"
srcDir = "{srcDir}"


# Deps

requires "nim >= {pkgMinNimVersion}"
"""
  mainFileTemplate = """proc sum*(a, b: int): int =
  a + b
"""
  testFileTemplate = """import
  std/unittest,
  {pkgName}

suite "Main":
  test "sum of two":
    assert sum(2, 3) == 5
"""
  testConfigFileTemplate = """--path:"../{srcDir}"
"""
  editorConfigTemplate = """root = true

[*]
end_of_line = lf
insert_final_newline = true

[*.nim]
indent_style = space
indent_size = 2
"""
  readmeTemplate = """<div align="center">

# {pkgName}
### {pkgDescription}

</div>
"""
  licenseList = @[
    "MIT",
    "GPL",
    "GPL 3.0",
    "LGPL",
    "Unlicense",
    "CC",
    "AFL-3.0",
  ]


proc initCommand*(
    help: bool = false,
    name: string = "",
    description: string = "Just another Nim package",
    version: string = "0.0.1",
    author: string = "",
    license: string = "MIT",
    minNimVersion: string = "1.6.14",
) =
  if help:
    styledEcho "Usage: ", fgYellow, "nmr ", fgMagenta, "init", fgWhite, " [options]\n"
    styledEcho "Create a new Nim project with nmr..\n"
    styledEcho "Options:"
    styledEcho fgYellow, "  -A", fgWhite, ",", fgYellow, "  --author", fgWhite, "            Specify the package author"
    styledEcho fgYellow, "  -n", fgWhite, ",", fgYellow, "  --name", fgWhite, "              Specify the package name"
    styledEcho fgYellow, "  -nv", fgWhite, ",", fgYellow, " --min-nim-version", fgWhite, "   Specify the min supported Nim version (default 1.6.14)"
    styledEcho fgYellow, "  -v", fgWhite, ",", fgYellow, "  --version", fgWhite, "           Specify the package version (default 0.0.1)"
    styledEcho fgYellow, "  -d", fgWhite, ",", fgYellow, "  --description", fgWhite, "       Specify the package description"
    styledEcho fgYellow, "  -Li", fgWhite, ",", fgYellow, " --license", fgWhite, "          Specify the package license (default MIT)"
    styledEcho fgYellow, "  -h", fgWhite, ",", fgYellow, "  --help", fgWhite, "              Show this help\n"
    styledEcho "Examples:"
    styledEcho fgYellow, "  nmr", fgMagenta, " init", fgBlue, " --name ", fgWhite, "myPackage", fgBlue, " -v ", fgWhite, "1.0.0"
    styledEcho fgYellow, "  nmr", fgMagenta, " init"
    return

  illwillInit(false, false)

  styledEcho "Initializing new ", fgYellow, "Nim", fgWhite, " project ...\n"

  var
    pkgName = enterValue("Package name", name)
  
  if dirExists(pkgName):
    var i = 0
    for file in walkDirRec(pkgName):
      inc i
      break
    if i > 0:
      styledEcho fgRed, "Error: ", fgWhite, "directory, ", fgYellow, pkgName , fgWhite, " is not empty!"
      return
  
  var
    pkgVersion = enterValue("Package version", version)
    pkgAuthor = enterValue("Package author", author)
    pkgDescription = enterValue("Package description", description)
    pkgMinNimVersion = enterValue("Minimum Nim version", minNimVersion)
    pkgLicense = chooseOption("Choose pacakge license", licenseList, license)
    srcDir = "src"
  

  if not dirExists(pkgName): createDir(pkgName)
  if not dirExists(pkgName / "src"): createDir(pkgName / "src")
  if not dirExists(pkgName / "tests"): createDir(pkgName / "tests")

  # Package main file
  createFile(pkgName / fmt"{pkgName}.nimble", fmt(nimbleTemplate))
  # Misc files
  createFile(pkgName / "README.md", fmt(readmeTemplate))
  createFile(pkgName / ".gitignore", fmt(gitignoreTemplate))
  createFile(pkgName / ".editorconfig", fmt(editorConfigTemplate))
  # Source files
  createFile(pkgName / srcDir / fmt"{pkgName}.nim", fmt(mainFileTemplate))
  # Tests
  createFile(pkgName / "tests" / "config.nims", fmt(testConfigFileTemplate))
  createFile(pkgName / "tests" / "test.nim", fmt(testFileTemplate))

  illwillDeinit()
