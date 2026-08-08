import SwiftUI
import WebKit
import UniformTypeIdentifiers
import VMDCore

struct MarkdownWebView: NSViewRepresentable {
    let fileURL: URL
    var model: ViewerModel?
    var showsSource = false

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
        context.coordinator.show(fileURL, source: showsSource)
        // Files from one vmd CLI invocation become tabs of that invocation's
        // window; the window only exists after the view attaches. Windows are
        // not restorable: relaunching would resurrect stale documents and
        // rebuild old tab groups that new windows then get merged into.
        DispatchQueue.main.async { [weak webView] in
            guard let window = webView?.window else { return }
            window.isRestorable = false
            WindowBatcher.adopt(window, showing: fileURL)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.watchedURL != fileURL || context.coordinator.showsSource != showsSource {
            context.coordinator.show(fileURL, source: showsSource)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private(set) var watchedURL: URL?
        private(set) var showsSource = false
        private var watcher: FileWatcher?
        private var pendingScrollY: Double?

        func show(_ url: URL, source: Bool) {
            watchedURL = url
            showsSource = source
            watcher = FileWatcher(url: url) { [weak self] in
                self?.reloadPreservingScroll()
            }
            webView?.load(URLRequest(url: MarkdownSchemeHandler.pageURL(for: url, source: source)))
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

    static func pageURL(for fileURL: URL, source: Bool = false) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = ""
        components.path = fileURL.standardizedFileURL.path
        if source {
            components.queryItems = [URLQueryItem(name: "view", value: "source")]
        }
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
            return try assetResponse(for: url)
        }

        let fileURL = URL(fileURLWithPath: url.path)
        let data = try Data(contentsOf: fileURL)
        if Self.markdownExtensions.contains(fileURL.pathExtension.lowercased()) {
            let text = String(decoding: data, as: UTF8.self)
            let wantsSource = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains { $0.name == "view" && $0.value == "source" } ?? false
            let html = wantsSource
                ? HTMLTemplate.sourcePage(title: fileURL.lastPathComponent, source: text)
                : HTMLTemplate.page(title: fileURL.lastPathComponent, body: MarkdownRenderer.html(from: text))
            return (Data(html.utf8), "text/html", "utf-8")
        }
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return (data, mimeType, nil)
    }

    private func assetResponse(for url: URL) throws -> (Data, String, String?) {
        let mimeTypes = [
            "js": "text/javascript",
            "css": "text/css",
            "woff2": "font/woff2",
        ]
        let components = url.pathComponents.filter { $0 != "/" }
        guard !components.contains(".."),
              let name = components.first,
              let mimeType = mimeTypes[url.pathExtension.lowercased()]
        else { throw URLError(.fileDoesNotExist) }

        let assetURL: URL?
        if name == "katex" {
            assetURL = Bundle.module.url(forResource: "katex", withExtension: nil)
                .map { components.dropFirst().reduce($0) { $0.appendingPathComponent($1) } }
        } else if components.count == 1, ["mermaid.min.js", "highlight.min.js", "highlight.css"].contains(name) {
            assetURL = Bundle.module.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: url.pathExtension
            )
        } else {
            assetURL = nil
        }
        guard let assetURL else { throw URLError(.fileDoesNotExist) }
        let encoding = mimeType.hasPrefix("font") ? nil : "utf-8"
        return (try Data(contentsOf: assetURL), mimeType, encoding)
    }
}
