const
  gitignoreTemplate* = """# Builds
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
  nimbleTemplate* = """# Package
verion = "{pkgVersion}"
author = "{pkgAuthor}"
description = "{pkgDescription}"
license = "{pkgLicense}"
srcDir = "{srcDir}"


# Deps

requires "nim >= {pkgMinNimVersion}"
"""
  mainFileTemplate* = """proc sum*(a, b: int): int =
  a + b
"""
  testFileTemplate* = """import
  std/unittest,
  {pkgName}

suite "Main":
  test "sum of two":
    assert sum(2, 3) == 5
"""
  testConfigFileTemplate* = """--path:"../{srcDir}"
"""
  editorConfigTemplate* = """root = true

[*]
end_of_line = lf
insert_final_newline = true

[*.nim]
indent_style = space
indent_size = 2
"""
  readmeTemplate* = """<div align="center">

# {pkgName}
### {pkgDescription}

</div>
"""
  licenseList* = @[
    "MIT",
    "GPL",
    "GPL 3.0",
    "LGPL",
    "Unlicense",
    "CC",
    "AFL-3.0",
  ]
