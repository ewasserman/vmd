# Development plan

## Milestone 1 — Rendering pipeline (VMDCore)

- [x] GFM → HTML via cmark-gfm (tables, strikethrough, autolink, task lists)
- [ ] HTML page template with GitHub-style CSS, light/dark via `prefers-color-scheme`
- [ ] Sanitization decision: keep cmark's safe defaults (raw HTML stripped) for v1

## Milestone 2 — Viewer app (VMDApp)

- [ ] Read-only document app: `DocumentGroup(viewing:)` with a `FileDocument` for markdown
- [ ] `WKWebView` wrapper (`NSViewRepresentable`) rendering the HTML template
- [ ] Load via `loadFileURL` with directory read access so relative images resolve
- [ ] Link policy: external links open in default browser; relative `.md` links open a new viewer window
- [ ] Window title = file name; sensible default window size

## Milestone 3 — App bundle

- [ ] `Makefile` + script to assemble `VMD.app` from the SPM build (Info.plist, executable, ad-hoc codesign)
- [ ] Info.plist declares the `net.daringfireball.markdown` document type so Finder "Open With" and `open` work
- [ ] `make install` → copies `VMD.app` to `/Applications`

## Milestone 4 — CLI (`vmd`)

- [ ] `vmd file.md` resolves the path and launches the app via `NSWorkspace`/bundle id (new window per file)
- [ ] Friendly errors: missing file, app not installed
- [ ] `make install` also links `vmd` into `/usr/local/bin`

## Milestone 5 — Polish

- [ ] Auto-reload on file change (DispatchSource file watcher), preserving scroll position
- [ ] App icon
- [ ] Recent files menu
- [ ] Cmd+P print / PDF export

## Milestone 6 — CI

- [ ] GitHub Actions: `swift build && swift test` on macOS
