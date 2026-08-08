import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Renders GitHub Flavored Markdown to an HTML fragment using cmark-gfm.
public enum MarkdownRenderer {
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist"]

    public static func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return "" }
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
        guard let rendered = cmark_render_html(document, CMARK_OPT_DEFAULT, extensions) else {
            return ""
        }
        defer { free(rendered) }
        return String(cString: rendered)
    }
}
