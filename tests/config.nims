--path:"../src"
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
