# Development plan

## Milestone 1 — Rendering pipeline (VMDCore) ✅

- [x] GFM → HTML via cmark-gfm (tables, strikethrough, autolink, task lists, footnotes)
- [x] Raw HTML passes through GitHub-style: tagfilter escapes dangerous tags, and a
      per-render CSP nonce blocks any markdown-supplied script from executing
- [x] Workaround for cmark-gfm's unterminated footnote-backref `aria-label`
- [x] HTML page template with GitHub-style CSS, light/dark via `prefers-color-scheme`
- [x] Mermaid diagrams: bundled `mermaid.min.js` (offline), injected only when a
      ```` ```mermaid ```` fence is present

## Milestone 2 — Viewer app (VMDApp) ✅

- [x] Read-only document app: `DocumentGroup(viewing:)` (open panel, recents, Finder integration)
- [x] `WKWebView` wrapper rendering via a custom `vmd:` URL scheme handler, so
      relative images and links resolve without temp files
- [x] Link policy: relative `.md` links navigate in-window (with back/forward);
      everything else opens externally
- [x] Auto-reload on file change (debounced, survives atomic saves, preserves scroll)
- [x] Window title = file name; 900×1000 default window

## Milestone 3 — App bundle ✅

- [x] `make app` assembles `dist/VMD.app` (Info.plist, resources, ad-hoc codesign)
- [x] Info.plist declares `net.daringfireball.markdown` so Finder "Open With" works
- [x] `make install` → `/Applications/VMD.app` + `vmd` CLI

## Milestone 4 — CLI (`vmd`) ✅

- [x] `vmd file.md [more.md ...]` resolves paths and opens windows via `NSWorkspace`
- [x] Friendly errors: usage, missing file, app not installed

## Milestone 5 — Polish

- [ ] App icon
- [ ] Heading anchor ids (in-page `#fragment` links)
- [ ] Syntax highlighting for fenced code blocks
- [ ] Find in page (⌘F)
- [ ] Print / PDF export

## Milestone 6 — CI ✅

- [x] GitHub Actions: `swift build && swift test` on macOS
