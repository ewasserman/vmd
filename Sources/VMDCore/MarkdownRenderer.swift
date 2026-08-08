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
        return repairFootnoteBackrefs(String(cString: rendered))
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
