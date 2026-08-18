import SwiftUI
import WebKit
import UniformTypeIdentifiers
import VMDCore

/// Bridges the focused document window's webview to SwiftUI (find bar) and
/// menu commands (find, print).
@MainActor
final class ViewerModel: ObservableObject {
    weak var webView: WKWebView?
    var fileURL: URL?
    @Published var isFindVisible = false
    @Published var showsSource = false
    // Persisted so new windows open with the layout the user last chose.
    @Published var usesFullWidth = UserDefaults.standard.object(forKey: "usesFullWidth") as? Bool ?? true {
        didSet { UserDefaults.standard.set(usesFullWidth, forKey: "usesFullWidth") }
    }

    func exportHTML() {
        guard let webView, let window = webView.window, let fileURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".html"
        let fullWidth = usesFullWidth
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                let markdown = try String(contentsOf: fileURL, encoding: .utf8)
                let html = HTMLTemplate.exportPage(
                    title: fileURL.lastPathComponent,
                    body: MarkdownRenderer.html(from: markdown),
                    assets: AssetStore(resourceBundleURL: Bundle.appResources.bundleURL),
                    fullWidth: fullWidth
                )
                try html.write(to: destination, atomically: true, encoding: .utf8)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func find(_ text: String, backwards: Bool = false) {
        guard let webView, !text.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(text, configuration: configuration) { _ in }
    }

    func endFinding() {
        isFindVisible = false
        webView?.evaluateJavaScript("window.getSelection().removeAllRanges()")
    }

    /// Shared across Page Setup and Print so paper size and orientation stick
    /// between the two panels, the way AppKit apps normally behave.
    private lazy var printInfo: NSPrintInfo = {
        let info = NSPrintInfo()
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 28
        info.rightMargin = 28
        return info
    }()

    func runPageLayout() {
        guard let window = webView?.window else { return }
        NSPageLayout().beginSheet(with: printInfo, modalFor: window, delegate: nil, didEnd: nil, contextInfo: nil)
    }

    func printDocument() {
        guard let webView, let window = webView.window else { return }
        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        // AppKit's default panel omits these; Safari's print dialog shows them.
        operation.printPanel.options.insert([.showsPaperSize, .showsOrientation, .showsScaling])
        // WKWebView's print view has a zero frame until it is sized explicitly.
        operation.view?.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
                height: printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin
            )
        )
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
}

extension FocusedValues {
    @Entry var viewerModel: ViewerModel?
}
