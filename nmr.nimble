# Package 

description = "A super-fast Nim package manager with automatic dependency graph and parallel installation."
author = "HapticX"
version = "0.0.1"
license = "MIT"
srcDir = "src"
installExt = @["nim"]
bin = @["cli/nmr"]

# Deps

requires "nim >= 1.6.6"

# CLI
requires "cligen >= 1.8.4"

# QR
requires "qrgen >= 3.1.0"
