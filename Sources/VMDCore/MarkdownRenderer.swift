import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Renders GitHub Flavored Markdown to an HTML fragment using cmark-gfm.
public enum MarkdownRenderer {
    /// "tagfilter" requires CMARK_OPT_UNSAFE: raw HTML passes through (as on
    /// github.com) but dangerous tags like <script> are escaped. The viewer
    /// additionally keeps page JavaScript disabled.
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]

    private static let options = CMARK_OPT_DEFAULT | CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES

    public static func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        // Math is pulled out before cmark runs so backslash sequences like \,
        // and \\ survive markdown escape processing, and restored afterwards.
        let (prepared, mathSegments) = extractMath(markdown)
        cmark_parser_feed(parser, prepared, prepared.utf8.count)

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let rendered = cmark_render_html(document, options, extensions) else {
            return ""
        }
        defer { free(rendered) }
        let html = addHeadingAnchors(repairFootnoteBackrefs(String(cString: rendered)))
        return restoreMath(html, segments: mathSegments)
    }

    private struct MathSegment {
        let source: String
        let content: String
        let display: Bool
    }

    private static func mathToken(_ index: Int) -> String { "vmdmathsegment\(index)end" }

    /// Replaces `$$...$$` and `$...$` (GitHub math rules: non-space characters
    /// just inside both inline delimiters, no digit after the closer — which
    /// keeps prose like "$5 and $10" literal) with inert alphanumeric tokens
    /// that pass through cmark untouched.
    private static func extractMath(_ markdown: String) -> (String, [MathSegment]) {
        guard markdown.contains("$") else { return (markdown, []) }
        let display = try! NSRegularExpression(pattern: "\\$\\$([\\s\\S]+?)\\$\\$")
        let inline = try! NSRegularExpression(pattern: "\\$(?![\\s$])([^$\\n]+?)(?<![\\s\\\\])\\$(?!\\d)")

        var segments: [MathSegment] = []
        var text = markdown
        for (pattern, isDisplay) in [(display, true), (inline, false)] {
            var result = ""
            var cursor = text.startIndex
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text),
                      let contentRange = Range(match.range(at: 1), in: text) else { continue }
                result += text[cursor..<range.lowerBound]
                result += mathToken(segments.count)
                segments.append(MathSegment(
                    source: String(text[range]),
                    content: String(text[contentRange]),
                    display: isDisplay
                ))
                cursor = range.upperBound
            }
            result += text[cursor...]
            text = result
        }
        return (text, segments)
    }

    /// Swaps math tokens back in: KaTeX `\(...\)` / `\[...\]` delimiters in
    /// prose, but the original `$...$` source wherever a token ended up inside
    /// `<pre>`/`<code>` (the raw-markdown scan can't see code regions).
    private static func restoreMath(_ html: String, segments: [MathSegment]) -> String {
        guard !segments.isEmpty else { return html }
        let protectedRegions = try! NSRegularExpression(pattern: "<pre[\\s\\S]*?</pre>|<code[\\s\\S]*?</code>")

        func substitute(_ text: String, protected: Bool) -> String {
            var result = text
            for (index, segment) in segments.enumerated() where result.contains(mathToken(index)) {
                let replacement = protected
                    ? escapeHTML(segment.source)
                    : segment.display
                        ? "\\[\(escapeHTML(segment.content))\\]"
                        : "\\(\(escapeHTML(segment.content))\\)"
                result = result.replacingOccurrences(of: mathToken(index), with: replacement)
            }
            return result
        }

        var result = ""
        var cursor = html.startIndex
        for match in protectedRegions.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            result += substitute(String(html[cursor..<range.lowerBound]), protected: false)
            result += substitute(String(html[range]), protected: true)
            cursor = range.upperBound
        }
        result += substitute(String(html[cursor...]), protected: false)
        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Adds GitHub-style `id` slugs to headings so `#fragment` links work.
    /// cmark emits attribute-less headings, and heading-like text inside code
    /// blocks is entity-escaped, so the pattern only matches real headings.
    private static func addHeadingAnchors(_ html: String) -> String {
        var seen: [String: Int] = [:]
        let pattern = try! NSRegularExpression(pattern: "<h([1-6])>(.*?)</h\\1>", options: [.dotMatchesLineSeparators])
        let full = NSRange(html.startIndex..., in: html)
        var result = ""
        var cursor = html.startIndex
        for match in pattern.matches(in: html, range: full) {
            guard let range = Range(match.range, in: html),
                  let levelRange = Range(match.range(at: 1), in: html),
                  let innerRange = Range(match.range(at: 2), in: html) else { continue }
            let level = html[levelRange]
            let inner = String(html[innerRange])
            var slug = slugify(inner)
            let count = seen[slug, default: 0]
            seen[slug] = count + 1
            if count > 0 { slug += "-\(count)" }
            result += html[cursor..<range.lowerBound]
            result += "<h\(level) id=\"\(slug)\">\(inner)</h\(level)>"
            cursor = range.upperBound
        }
        result += html[cursor...]
        return result
    }

    private static func slugify(_ headingHTML: String) -> String {
        let text = headingHTML
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .lowercased()
        var slug = ""
        for character in text {
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                slug.append(character)
            } else if character == " " {
                slug.append("-")
            }
        }
        return slug
    }

    /// cmark-gfm (src/html.c) emits footnote backrefs with an unterminated
    /// aria-label attribute, which makes the HTML parser swallow everything
    /// up to the next quote character. Close the attribute.
    private static func repairFootnoteBackrefs(_ html: String) -> String {
        html.replacingOccurrences(
            of: #"(aria-label="Back to reference [0-9-]+)↩</a>"#,
            with: "$1\">↩</a>",
            options: .regularExpression
        )
    }
}
