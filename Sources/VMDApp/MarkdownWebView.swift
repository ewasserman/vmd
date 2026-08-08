import SwiftUI
import WebKit
import UniformTypeIdentifiers
import VMDCore

struct MarkdownWebView: NSViewRepresentable {
    let fileURL: URL
    var model: ViewerModel?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(MarkdownSchemeHandler(), forURLScheme: MarkdownSchemeHandler.scheme)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .textBackgroundColor
        context.coordinator.webView = webView
        model?.webView = webView
        context.coordinator.show(fileURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.watchedURL != fileURL {
            context.coordinator.show(fileURL)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private(set) var watchedURL: URL?
        private var watcher: FileWatcher?
        private var pendingScrollY: Double?

        func show(_ url: URL) {
            watchedURL = url
            watcher = FileWatcher(url: url) { [weak self] in
                self?.reloadPreservingScroll()
            }
            webView?.load(URLRequest(url: MarkdownSchemeHandler.pageURL(for: url)))
        }

        private func reloadPreservingScroll() {
            guard let webView else { return }
            webView.evaluateJavaScript("window.scrollY") { [weak self] value, _ in
                self?.pendingScrollY = value as? Double
                self?.webView?.reload()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let y = pendingScrollY {
                pendingScrollY = nil
                webView.evaluateJavaScript("window.scrollTo(0, \(y))")
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            switch url.scheme {
            case MarkdownSchemeHandler.scheme, "about", nil:
                return .allow
            default:
                // External links (http, mailto, file, ...) leave the viewer.
                NSWorkspace.shared.open(url)
                return .cancel
            }
        }
    }
}

/// Serves content for vmd: URLs.
///
/// - `vmd:///absolute/path` — markdown files are rendered to a full HTML
///   page; anything else (images, etc.) is served raw, so relative links in
///   documents resolve naturally.
/// - `vmd://assets/<name>` — assets bundled with the app (mermaid).
final class MarkdownSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "vmd"

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "txt", "text"]

    static func pageURL(for fileURL: URL) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = ""
        components.path = fileURL.standardizedFileURL.path
        return components.url!
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        do {
            let (data, mimeType, encoding) = try response(for: url)
            task.didReceive(URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: encoding
            ))
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func response(for url: URL) throws -> (Data, String, String?) {
        if url.host == "assets" {
            let assets: [String: (resource: String, ext: String, mime: String)] = [
                "mermaid.min.js": ("mermaid.min", "js", "text/javascript"),
                "highlight.min.js": ("highlight.min", "js", "text/javascript"),
                "highlight.css": ("highlight", "css", "text/css"),
            ]
            guard let asset = assets[url.lastPathComponent],
                  let assetURL = Bundle.module.url(forResource: asset.resource, withExtension: asset.ext)
            else { throw URLError(.fileDoesNotExist) }
            return (try Data(contentsOf: assetURL), asset.mime, "utf-8")
        }

        let fileURL = URL(fileURLWithPath: url.path)
        let data = try Data(contentsOf: fileURL)
        if Self.markdownExtensions.contains(fileURL.pathExtension.lowercased()) {
            let html = HTMLTemplate.page(
                title: fileURL.lastPathComponent,
                body: MarkdownRenderer.html(from: String(decoding: data, as: UTF8.self))
            )
            return (Data(html.utf8), "text/html", "utf-8")
        }
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return (data, mimeType, nil)
    }
}
