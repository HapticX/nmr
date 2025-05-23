import
  std/asyncdispatch,
  std/unittest,
  cli/git_utils


suite "GitHub utils":
  test "Get refs":
    echo waitFor getRefs("https://github.com/HapticX/happyx", heads = false, pulls = false)
