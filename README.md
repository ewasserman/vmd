# vmd

A simple, fast macOS markdown viewer with GitHub Flavored Markdown support, plus a `vmd` CLI that pops open a viewer window for any `.md` file.

- **GFM**: tables, task lists, strikethrough, autolinks, footnotes
- **Mermaid** diagrams, **LaTeX math** (`$…$`, `$$…$$`, ` ```math ` fences via KaTeX),
  and **syntax highlighting** — all bundled, works offline
- GitHub-style typography with automatic light/dark mode
- Live reload: the window re-renders (preserving scroll) when the file changes
- Relative images and links just work; external links open in your browser
- Heading anchors, find in page (⌘F), print / save as PDF (⌘P), and a
  syntax-highlighted source view (⇧⌘U or the toolbar toggle)
- Export as a single self-contained HTML file (⇧⌘E, or `vmd --html file.md > out.html`) —
  diagrams, math fonts, and highlighting all embedded, works offline
- Raw HTML renders GitHub-style — dangerous tags are filtered and a strict CSP
  keeps markdown-supplied content inert

## Install

With [Homebrew](https://brew.sh):

```sh
brew install ewasserman/tap/vmd
```

The app builds from source on your machine, so there is no Gatekeeper
quarantine and no notarization requirement.

Or from a checkout:

```sh
make install        # /Applications/VMD.app + ~/.local/bin/vmd — no sudo needed
```

Set `PREFIX` for a different CLI location, e.g. `make install PREFIX=/usr/local` (needs sudo).

## Use

```sh
vmd README.md       # open a viewer window
vmd a.md b.md       # multiple files become tabs of one new window
vmd --html a.md     # standalone HTML on stdout (full width, like the app)
vmd --html --narrow a.md   # ... constrained to a readable column instead
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

## Releasing

Releases are automated: pushes to `main` with [conventional commits](https://www.conventionalcommits.org)
(`fix:`/`perf:` → patch, `feat:` → minor, `!`/`BREAKING CHANGE` → major) are
tagged, released, and rolled into the Homebrew formula by CI. Other commit
types (`docs:`, `ci:`, `chore:`, ...) release nothing.

See [PLAN.md](PLAN.md) for the development plan.
