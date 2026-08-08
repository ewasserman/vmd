import Testing
@testable import VMDCore

@Suite struct MarkdownRendererTests {
    @Test func rendersBasicMarkdown() {
        let html = MarkdownRenderer.html(from: "# Hello\n\nSome *text*.")
        #expect(html.contains("<h1>Hello</h1>"))
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

    @Test func mermaidFencesKeepLanguageClass() {
        let html = MarkdownRenderer.html(from: "```mermaid\ngraph TD; A-->B;\n```")
        #expect(html.contains("language-mermaid"))
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
}
