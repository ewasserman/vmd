# vmd

A simple, fast macOS markdown viewer with GitHub Flavored Markdown support, plus a `vmd` CLI that pops open a viewer window for any `.md` file.

- **GFM**: tables, task lists, strikethrough, autolinks, footnotes
- **Mermaid** diagrams (bundled, works offline)
- GitHub-style typography with automatic light/dark mode
- Live reload: the window re-renders (preserving scroll) when the file changes
- Relative images and links just work; external links open in your browser
- Raw HTML renders GitHub-style — dangerous tags are filtered and a strict CSP
  keeps markdown-supplied content inert

## Install

```sh
make install        # /Applications/VMD.app + ~/.local/bin/vmd — no sudo needed
```

Set `PREFIX` for a different CLI location, e.g. `make install PREFIX=/usr/local` (needs sudo).

## Use

```sh
vmd README.md       # open a viewer window
vmd a.md b.md       # one window per file
```

Or open `.md` files from Finder via "Open With → VMD", or ⌘O inside the app.

## Develop

```sh
swift build         # build everything
swift test          # run tests
make run            # build dist/VMD.app and launch it
```

## Layout

- `Sources/VMDCore` — GFM → HTML via [cmark-gfm](https://github.com/apple/swift-cmark), plus the HTML/CSS page template
- `Sources/VMDApp` — SwiftUI document app; a custom `vmd:` URL scheme handler feeds `WKWebView`
- `Sources/vmd` — CLI launcher

See [PLAN.md](PLAN.md) for the development plan.
