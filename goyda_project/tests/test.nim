import
  std/unittest,
  goyda_project

suite "Main":
  test "sum of two":
    assert sum(2, 3) == 5
