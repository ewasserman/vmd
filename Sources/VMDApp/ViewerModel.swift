import SwiftUI
import WebKit

/// Bridges the focused document window's webview to SwiftUI (find bar) and
/// menu commands (find, print).
@MainActor
final class ViewerModel: ObservableObject {
    weak var webView: WKWebView?
    @Published var isFindVisible = false

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

    func printDocument() {
        guard let webView, let window = webView.window else { return }
        let printInfo = NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 28
        printInfo.rightMargin = 28
        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
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
