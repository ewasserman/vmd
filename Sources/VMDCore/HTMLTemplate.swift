import Foundation

/// Wraps a rendered HTML fragment in a full page with GitHub-style CSS.
///
/// Scripts are gated by a per-render CSP nonce: only template-injected
/// scripts run; anything smuggled in via raw HTML in the markdown is blocked.
public enum HTMLTemplate {
    /// URLs the app's vmd: scheme handler serves bundled assets from.
    public static let mermaidScriptURL = "vmd://assets/mermaid.min.js"
    public static let highlightScriptURL = "vmd://assets/highlight.min.js"
    public static let highlightStylesheetURL = "vmd://assets/highlight.css"
    public static let katexScriptURL = "vmd://assets/katex/katex.min.js"
    public static let katexAutoRenderURL = "vmd://assets/katex/auto-render.min.js"
    public static let katexStylesheetURL = "vmd://assets/katex/katex.min.css"

    /// A page showing raw markdown source as a highlighted code block.
    public static func sourcePage(title: String, source: String, fullWidth: Bool = false) -> String {
        page(
            title: title,
            body: "<pre><code class=\"language-markdown\">\(escape(source))</code></pre>",
            articleClass: articleClass("markdown-body source-view", fullWidth: fullWidth)
        )
    }

    public static func page(title: String, body: String, fullWidth: Bool = false) -> String {
        page(title: title, body: body, articleClass: articleClass("markdown-body", fullWidth: fullWidth))
    }

    private static func articleClass(_ base: String, fullWidth: Bool) -> String {
        fullWidth ? base + " full-width" : base
    }

    private static func page(title: String, body: String, articleClass: String) -> String {
        let nonce = UUID().uuidString
        var head = ""
        var scripts = ""
        if body.contains("<pre><code") {
            // The stylesheet link precedes our inline CSS so our overrides win ties.
            head += "<link rel=\"stylesheet\" href=\"\(highlightStylesheetURL)\">\n"
            scripts += """
            <script nonce="\(nonce)" src="\(highlightScriptURL)"></script>
            <script nonce="\(nonce)">\(highlightInit)</script>
            """
        }
        if body.contains("language-mermaid") {
            scripts += """
            <script nonce="\(nonce)" src="\(mermaidScriptURL)"></script>
            <script nonce="\(nonce)">\(mermaidInit)</script>
            """
        }
        if body.contains("\\(") || body.contains("\\[") || body.contains("language-math") {
            head += "<link rel=\"stylesheet\" href=\"\(katexStylesheetURL)\">\n"
            scripts += """
            <script nonce="\(nonce)" src="\(katexScriptURL)"></script>
            <script nonce="\(nonce)" src="\(katexAutoRenderURL)"></script>
            <script nonce="\(nonce)">\(katexInit)</script>
            """
        }
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src vmd: data: http: https:; media-src vmd:; style-src 'unsafe-inline' vmd:; font-src vmd: data:; script-src 'nonce-\(nonce)'">
        <title>\(escape(title))</title>
        \(head)<style>\(css)</style>
        </head>
        <body><article class="\(articleClass)">
        \(body)
        </article>\(scripts)</body>
        </html>
        """
    }

    /// A fully self-contained page for saving outside the app: highlighting,
    /// mermaid, and KaTeX (including fonts) are embedded from the given asset
    /// store, so the file works offline with no external references. Scripts
    /// are embedded as base64 data: URIs — minified libraries contain
    /// sequences like `<script` that break HTML parsing when inlined as text.
    public static func exportPage(title: String, body: String, assets: AssetStore) -> String {
        var head = ""
        var scripts = ""
        if body.contains("<pre><code"), let css = assets.text("highlight.css"), let js = assets.data("highlight.min.js") {
            head += "<style>\(css)</style>\n"
            scripts += embeddedScript(js) + "<script>\(highlightInit)</script>"
        }
        if body.contains("language-mermaid"), let js = assets.data("mermaid.min.js") {
            scripts += embeddedScript(js) + "<script>\(mermaidInit)</script>"
        }
        if body.contains("\\(") || body.contains("\\[") || body.contains("language-math"),
           let katexCSS = assets.text("katex/katex.min.css"),
           let katexJS = assets.data("katex/katex.min.js"),
           let autoRenderJS = assets.data("katex/auto-render.min.js") {
            head += "<style>\(inlineKaTeXFonts(katexCSS, assets: assets))</style>\n"
            scripts += embeddedScript(katexJS) + embeddedScript(autoRenderJS) + "<script>\(katexInit)</script>"
        }
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(escape(title))</title>
        \(head)<style>\(css)</style>
        </head>
        <body><article class="markdown-body">
        \(body)
        </article>\(scripts)</body>
        </html>
        """
    }

    private static func embeddedScript(_ data: Data) -> String {
        "<script src=\"data:text/javascript;base64,\(data.base64EncodedString())\"></script>"
    }

    /// Rewrites `url(fonts/*.woff2)` references to embedded data: URIs.
    private static func inlineKaTeXFonts(_ css: String, assets: AssetStore) -> String {
        let pattern = try! NSRegularExpression(pattern: "url\\(fonts/([^)]+\\.woff2)\\)")
        var result = ""
        var cursor = css.startIndex
        for match in pattern.matches(in: css, range: NSRange(css.startIndex..., in: css)) {
            guard let range = Range(match.range, in: css),
                  let nameRange = Range(match.range(at: 1), in: css) else { continue }
            result += css[cursor..<range.lowerBound]
            if let font = assets.data("katex/fonts/\(css[nameRange])") {
                result += "url(data:font/woff2;base64,\(font.base64EncodedString()))"
            } else {
                result += css[range]
            }
            cursor = range.upperBound
        }
        result += css[cursor...]
        return result
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let highlightInit = """
    document.querySelectorAll('pre > code').forEach(function (el) {
      if (el.classList.contains('language-mermaid') || el.classList.contains('language-math')) return;
      hljs.highlightElement(el);
    });
    """

    private static let katexInit = """
    document.querySelectorAll('pre > code.language-math').forEach(function (code) {
      var holder = document.createElement('div');
      holder.className = 'math-display';
      katex.render(code.textContent, holder, { displayMode: true, throwOnError: false });
      code.parentElement.replaceWith(holder);
    });
    renderMathInElement(document.body, {
      delimiters: [
        { left: '\\\\[', right: '\\\\]', display: true },
        { left: '\\\\(', right: '\\\\)', display: false }
      ],
      throwOnError: false
    });
    """

    private static let mermaidInit = """
    (function () {
      var blocks = document.querySelectorAll('pre > code.language-mermaid');
      blocks.forEach(function (code) {
        var holder = document.createElement('pre');
        holder.className = 'mermaid';
        holder.textContent = code.textContent;
        code.parentElement.replaceWith(holder);
      });
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'
      });
      mermaid.run();
    })();
    """

    private static let css = """
    :root {
      color-scheme: light dark;
      --bg: #ffffff;
      --fg: #1f2328;
      --muted: #59636e;
      --border: #d1d9e0;
      --code-bg: #f6f8fa;
      --link: #0969da;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0d1117;
        --fg: #e6edf3;
        --muted: #9198a1;
        --border: #3d444d;
        --code-bg: #151b23;
        --link: #4493f8;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--fg);
      font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      text-rendering: optimizeLegibility;
    }
    .markdown-body {
      max-width: 780px;
      margin: 0 auto;
      padding: 2.5rem 2rem 6rem;
      word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 {
      margin: 24px 0 16px;
      font-weight: 600;
      line-height: 1.25;
    }
    h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: .875em; }
    h6 { font-size: .85em; color: var(--muted); }
    .markdown-body > *:first-child { margin-top: 0; }
    p, ul, ol, table, pre, blockquote { margin: 0 0 16px; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    code, pre, kbd {
      font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, monospace;
    }
    code {
      font-size: 85%;
      background: var(--code-bg);
      padding: .2em .4em;
      border-radius: 6px;
    }
    pre {
      background: var(--code-bg);
      padding: 16px;
      border-radius: 8px;
      overflow-x: auto;
      line-height: 1.45;
    }
    pre code { background: transparent; padding: 0; font-size: 85%; }
    pre code.hljs { background: transparent; padding: 0; }
    pre.mermaid {
      background: transparent;
      display: flex;
      justify-content: center;
    }
    kbd {
      font-size: 85%;
      padding: .15em .4em;
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-bottom-width: 3px;
      border-radius: 6px;
    }
    blockquote {
      padding: 0 1em;
      color: var(--muted);
      border-left: .25em solid var(--border);
    }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: .25em; }
    li.task-list-item, li:has(> input[type="checkbox"]:disabled) { list-style: none; }
    li > input[type="checkbox"]:disabled {
      margin: 0 .4em .2em -1.5em;
      vertical-align: middle;
    }
    table {
      border-collapse: collapse;
      border-spacing: 0;
      display: block;
      max-width: 100%;
      overflow-x: auto;
    }
    th, td { border: 1px solid var(--border); padding: 6px 13px; }
    th { font-weight: 600; }
    tbody tr:nth-child(2n) { background: var(--code-bg); }
    img { max-width: 100%; height: auto; }
    hr { border: 0; height: 1px; background: var(--border); margin: 24px 0; }
    .source-view { max-width: 1100px; }
    .markdown-body.full-width { max-width: none; }
    .footnotes {
      margin-top: 32px;
      font-size: 85%;
      color: var(--muted);
      border-top: 1px solid var(--border);
    }
    """
}
