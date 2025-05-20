import
  std/terminal,
  QRgen,
  ../utils


proc helpCommand*() =
  centeredEcho "", fgYellow, "NMR", fgWhite, " — Nim Package Manager ", fgRed, "v0.0.1"
  let qr = newQR("clk.li/fhP") # https://github.com/HapticX/nmr
  qr.printTerminalBeaty
