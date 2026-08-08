import Foundation

/// Wraps a rendered HTML fragment in a full page with GitHub-style CSS.
///
/// Scripts are gated by a per-render CSP nonce: only template-injected
/// scripts run; anything smuggled in via raw HTML in the markdown is blocked.
public enum HTMLTemplate {
    /// URL the app's vmd: scheme handler serves bundled assets from.
    public static let mermaidScriptURL = "vmd://assets/mermaid.min.js"

    public static func page(title: String, body: String) -> String {
        let nonce = UUID().uuidString
        let needsMermaid = body.contains("language-mermaid")
        let scripts = needsMermaid ? """
        <script nonce="\(nonce)" src="\(mermaidScriptURL)"></script>
        <script nonce="\(nonce)">\(mermaidInit)</script>
        """ : ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src vmd: data: http: https:; media-src vmd:; style-src 'unsafe-inline'; font-src vmd: data:; script-src 'nonce-\(nonce)'">
        <title>\(escape(title))</title>
        <style>\(css)</style>
        </head>
        <body><article class="markdown-body">
        \(body)
        </article>\(scripts)</body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

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
    .footnotes {
      margin-top: 32px;
      font-size: 85%;
      color: var(--muted);
      border-top: 1px solid var(--border);
    }
    """
}
