<div align="center">

# NMR
### Nim pkg Manager

</div>


## Get Started

to start you should just install it and use:
```shell
nimble install nmr
```

and run:
```shell
nmr
```


## Commands
Run `nmr <command> --help` for detailed usage.

List of available commands:
- [x] `init` - Initialize a new project
- [x] `install|i` - Install package(s) and deps
- [ ] `update` - Update package(s) by semver
- [x] `upgrade|up` - Upgrade packages list to latest
- [ ] `remove` - Remove package(s)
- [x] `deps-graph|dg` - Show dependency graph
- [x] `clean-cache|clnc` - Show dependency graph
- [ ] `publish` - Publish a package
- [x] `search|s` - Search for packages
- [x] `info` - Shows info about package


## How It Works
`nmr` keeps all your dependencies locally in one folder - `deps`.

When you install any libraries via `nmr`, it finds any `FILENAME.nim.cfg` and `config.nims` inside your project and injects into these config files `--path:"..."` lines for dependencies work.

Also `nmr` creates `.cache` folder inside your project to keep all cached dependencies to use it in `deps-graph` and `install` commands.
