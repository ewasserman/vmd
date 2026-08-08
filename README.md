# vmd

A simple macOS markdown viewer with GitHub Flavored Markdown support, plus a `vmd` CLI that opens a viewer window for any `.md` file.

## Layout

- `VMDCore` — shared library: GFM → HTML rendering via [cmark-gfm](https://github.com/apple/swift-cmark) (tables, strikethrough, autolinks, task lists)
- `VMDApp` — the SwiftUI viewer app (`VMD.app`)
- `vmd` — command-line launcher: `vmd README.md` pops open a viewer window

## Building

```sh
swift build          # build everything
swift test           # run tests
swift run vmd <file> # run the CLI
```

## Status

Scaffold — see [PLAN.md](PLAN.md) for the development plan.
