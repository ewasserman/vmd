import Foundation
import Testing
@testable import VMDCore

@Suite struct MarkdownRendererTests {
    @Test func rendersBasicMarkdown() {
        let html = MarkdownRenderer.html(from: "# Hello\n\nSome *text*.")
        #expect(html.contains("<h1 id=\"hello\">Hello</h1>"))
        #expect(html.contains("<em>text</em>"))
    }

    @Test func rendersGFMTables() {
        let html = MarkdownRenderer.html(from: "| a | b |\n|---|---|\n| 1 | 2 |")
        #expect(html.contains("<table>"))
    }

    @Test func rendersStrikethrough() {
        let html = MarkdownRenderer.html(from: "~~gone~~")
        #expect(html.contains("<del>gone</del>"))
    }

    @Test func rendersTaskLists() {
        let html = MarkdownRenderer.html(from: "- [x] done\n- [ ] todo")
        #expect(html.contains("type=\"checkbox\""))
    }

    @Test func autolinksBareURLs() {
        let html = MarkdownRenderer.html(from: "visit https://example.com now")
        #expect(html.contains("<a href=\"https://example.com\">"))
    }

    @Test func rendersFootnotes() {
        let html = MarkdownRenderer.html(from: "note[^1]\n\n[^1]: the footnote")
        #expect(html.contains("class=\"footnotes\""))
    }

    @Test func footnoteBackrefAttributeIsTerminated() {
        // Guards the workaround for cmark-gfm's unterminated aria-label,
        // which otherwise swallows all following markup into the attribute.
        let html = MarkdownRenderer.html(from: "note[^1]\n\n[^1]: the footnote")
        #expect(html.contains("aria-label=\"Back to reference 1\">"))
    }

    @Test func passesThroughRawHTMLButFiltersDangerousTags() {
        let html = MarkdownRenderer.html(from: "<img src=\"x.png\">\n\n<script>alert(1)</script>")
        #expect(html.contains("<img src=\"x.png\">"))
        #expect(!html.contains("<script>"))
    }

    @Test func addsGitHubStyleHeadingAnchors() {
        let html = MarkdownRenderer.html(from: "# Hello World!\n\n## Hello World!\n\n### With `code` too")
        #expect(html.contains("<h1 id=\"hello-world\">"))
        #expect(html.contains("<h2 id=\"hello-world-1\">"))
        #expect(html.contains("<h3 id=\"with-code-too\">"))
    }

    @Test func wrapsInlineAndDisplayMath() {
        let html = MarkdownRenderer.html(from: "Euler: $e^{i\\pi} + 1 = 0$ inline.\n\n$$\\int_0^1 x\\,dx$$")
        #expect(html.contains("\\(e^{i\\pi} + 1 = 0\\)"))
        #expect(html.contains("\\[\\int_0^1 x\\,dx\\]"))
    }

    @Test func leavesDollarProseAlone() {
        let html = MarkdownRenderer.html(from: "It costs $5 and $10 total, or $5-$8 on sale.")
        #expect(!html.contains("\\("))
    }

    @Test func leavesMathInCodeBlocksAlone() {
        let html = MarkdownRenderer.html(from: "`$x + y$`\n\n```\n$a + b$\n```")
        #expect(!html.contains("\\(x + y\\)"))
        #expect(!html.contains("\\(a + b\\)"))
    }

    @Test func mermaidFencesKeepLanguageClass() {
        let html = MarkdownRenderer.html(from: "```mermaid\ngraph TD; A-->B;\n```")
        #expect(html.contains("language-mermaid"))
    }
}

@Suite struct ExportPageTests {
    private func makeStore() throws -> (AssetStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vmd-export-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("katex/fonts"), withIntermediateDirectories: true
        )
        try "/* hl css */".write(to: dir.appendingPathComponent("highlight.css"), atomically: true, encoding: .utf8)
        try "hljs=1".write(to: dir.appendingPathComponent("highlight.min.js"), atomically: true, encoding: .utf8)
        try "mermaid=1".write(to: dir.appendingPathComponent("mermaid.min.js"), atomically: true, encoding: .utf8)
        try "@font-face{src:url(fonts/K.woff2)}".write(
            to: dir.appendingPathComponent("katex/katex.min.css"), atomically: true, encoding: .utf8)
        try "katex=1".write(to: dir.appendingPathComponent("katex/katex.min.js"), atomically: true, encoding: .utf8)
        try "ar=1".write(to: dir.appendingPathComponent("katex/auto-render.min.js"), atomically: true, encoding: .utf8)
        try Data("F".utf8).write(to: dir.appendingPathComponent("katex/fonts/K.woff2"))
        return (AssetStore(resourceBundleURL: dir), dir)
    }

    @Test func embedsEverythingWithNoExternalReferences() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = """
        <pre><code class="language-swift">let x = 1</code></pre>
        <pre><code class="language-mermaid">graph TD;</code></pre>
        <p>\\(x^2\\)</p>
        """
        let page = HTMLTemplate.exportPage(title: "t", body: body, assets: store)
        #expect(page.contains("/* hl css */"))
        #expect(page.contains("data:text/javascript;base64,"))
        #expect(page.contains("url(data:font/woff2;base64,"))
        #expect(!page.contains("vmd://"))
        #expect(!page.contains("http://"))
        #expect(!page.contains("https://"))
    }

    @Test func plainDocumentEmbedsNothing() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let page = HTMLTemplate.exportPage(title: "t", body: "<p>hi</p>", assets: store)
        #expect(!page.contains("data:text/javascript"))
        #expect(page.contains("<p>hi</p>"))
    }

    @Test func carriesFullWidthIntoTheExportedFile() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let framed = HTMLTemplate.exportPage(title: "t", body: "<p>hi</p>", assets: store)
        #expect(framed.contains("<article class=\"markdown-body\">"))

        let wide = HTMLTemplate.exportPage(title: "t", body: "<p>hi</p>", assets: store, fullWidth: true)
        #expect(wide.contains("<article class=\"markdown-body full-width\">"))
        #expect(wide.contains(".markdown-body.full-width { max-width: none; }"))
    }
}

@Suite struct HTMLTemplateTests {
    @Test func wrapsBodyInPage() {
        let page = HTMLTemplate.page(title: "a & b", body: "<p>hi</p>")
        #expect(page.contains("<p>hi</p>"))
        #expect(page.contains("<title>a &amp; b</title>"))
        #expect(page.contains("Content-Security-Policy"))
    }

    @Test func injectsMermaidOnlyWhenNeeded() {
        let plain = HTMLTemplate.page(title: "t", body: "<p>hi</p>")
        #expect(!plain.contains(HTMLTemplate.mermaidScriptURL))

        let diagram = HTMLTemplate.page(title: "t", body: "<pre><code class=\"language-mermaid\">graph TD;</code></pre>")
        #expect(diagram.contains(HTMLTemplate.mermaidScriptURL))
    }

    @Test func injectsKaTeXOnlyWhenMathPresent() {
        let plain = HTMLTemplate.page(title: "t", body: "<p>hi</p>")
        #expect(!plain.contains(HTMLTemplate.katexScriptURL))

        let math = HTMLTemplate.page(title: "t", body: "<p>\\(x^2\\)</p>")
        #expect(math.contains(HTMLTemplate.katexScriptURL))
        #expect(math.contains(HTMLTemplate.katexStylesheetURL))

        let fence = HTMLTemplate.page(title: "t", body: "<pre><code class=\"language-math\">x^2</code></pre>")
        #expect(fence.contains(HTMLTemplate.katexScriptURL))
    }

    @Test func fullWidthAddsClassOverridingMaxWidth() {
        let framed = HTMLTemplate.page(title: "t", body: "<p>hi</p>")
        #expect(!framed.contains("full-width\""))

        let wide = HTMLTemplate.page(title: "t", body: "<p>hi</p>", fullWidth: true)
        #expect(wide.contains("<article class=\"markdown-body full-width\">"))
        #expect(wide.contains(".markdown-body.full-width { max-width: none; }"))

        let wideSource = HTMLTemplate.sourcePage(title: "t", source: "# Hi", fullWidth: true)
        #expect(wideSource.contains("<article class=\"markdown-body source-view full-width\">"))
    }

    @Test func sourcePageShowsEscapedMarkdownWithHighlighting() {
        let page = HTMLTemplate.sourcePage(title: "t", source: "# Hi <b>\n\n$x$")
        #expect(page.contains("class=\"language-markdown\""))
        #expect(page.contains("# Hi &lt;b&gt;"))
        #expect(page.contains(HTMLTemplate.highlightScriptURL))
    }

    @Test func injectsHighlightingOnlyForCodeBlocks() {
        let plain = HTMLTemplate.page(title: "t", body: "<p>hi <code>x</code></p>")
        #expect(!plain.contains(HTMLTemplate.highlightScriptURL))

        let code = HTMLTemplate.page(title: "t", body: "<pre><code class=\"language-swift\">let x = 1</code></pre>")
        #expect(code.contains(HTMLTemplate.highlightScriptURL))
        #expect(code.contains(HTMLTemplate.highlightStylesheetURL))
    }
}
