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

        cmark_parser_feed(parser, markdown, markdown.utf8.count)

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let rendered = cmark_render_html(document, options, extensions) else {
            return ""
        }
        defer { free(rendered) }
        return addHeadingAnchors(repairFootnoteBackrefs(String(cString: rendered)))
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
