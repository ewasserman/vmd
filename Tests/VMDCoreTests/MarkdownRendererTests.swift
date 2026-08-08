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
}
