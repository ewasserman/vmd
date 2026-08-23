import SwiftUI
import WebKit
import UniformTypeIdentifiers
import VMDCore

/// Bridges the focused document window's webview to SwiftUI (find bar) and
/// menu commands (find, print, share).
@MainActor
final class ViewerModel: NSObject, ObservableObject {
    weak var webView: WKWebView?
    var fileURL: URL?
    /// The toolbar's Share button, registered by the view so the share
    /// popover can hang off it however the action was invoked.
    weak var shareAnchor: NSView?
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

    func sharePDF() {
        writePDFToShare { [weak self] url in
            guard let self else { return }
            if !presentSharePicker(for: [url]) {
                discardShareDirectory(for: url)
            }
        }
    }

    /// Menu path: the File ▸ Share submenu names a service directly, so no
    /// picker is involved.
    func sharePDF(via service: NSSharingService) {
        writePDFToShare { [weak self] url in
            guard let self else { return }
            // Retained while it runs; a service performs asynchronously and
            // would otherwise deallocate mid-share.
            activeService = service
            service.perform(withItems: [url])
        }
    }

    private var activeService: NSSharingService?

    /// Producing the file and presenting the picker stay separate so other
    /// payloads can be shared later without touching the presentation side.
    private func writePDFToShare(completion: @escaping (URL) -> Void) {
        guard let webView, let window = webView.window, let fileURL,
              // NSPrintInfo is shared with Page Setup and Print…, which must
              // keep printing to a printer rather than to a file.
              let info = printInfo.copy() as? NSPrintInfo
        else { return }
        sweepStaleShareDirectories()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.shareDirectoryPrefix + UUID().uuidString, isDirectory: true)
        // The recipient sees this file name, so name it after the document.
        let destination = directory
            .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("pdf")
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil
        else { return }

        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL.rawValue as NSString] = destination as NSURL
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // WKWebView's print view has a zero frame until it is sized explicitly.
        operation.view?.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: info.paperSize.width - info.leftMargin - info.rightMargin,
                height: info.paperSize.height - info.topMargin - info.bottomMargin
            )
        )
        // The operation finishes after this call returns, so the picker waits
        // for the callback rather than opening on a file that isn't there yet.
        pendingShares[ObjectIdentifier(operation)] = (destination, completion)
        operation.runModal(
            for: window,
            delegate: self,
            didRun: #selector(sharedFileDidPrint(_:success:contextInfo:)),
            contextInfo: nil
        )
    }

    /// Keyed by operation: a second Share started before the first finishes
    /// would otherwise have its entry consumed by the earlier callback.
    private var pendingShares: [ObjectIdentifier: (url: URL, completion: (URL) -> Void)] = [:]

    // nonisolated because a panel-less NSPrintOperation invokes the didRun
    // selector from its own worker thread, not the main thread.
    @objc nonisolated private func sharedFileDidPrint(
        _ operation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        let key = ObjectIdentifier(operation)
        Task { @MainActor [weak self] in
            guard let self, let pending = pendingShares.removeValue(forKey: key) else { return }
            guard success, FileManager.default.fileExists(atPath: pending.url.path) else {
                discardShareDirectory(for: pending.url)
                return
            }
            pending.completion(pending.url)
        }
    }

    /// Held for as long as the popover is up: a picker that only lives in the
    /// presenting scope deallocates before it can show anything.
    private var sharingPicker: NSSharingServicePicker?
    /// The file the visible picker is offering, so a cancelled share can throw
    /// it away again.
    private var sharedFileURL: URL?

    private func presentSharePicker(for items: [Any]) -> Bool {
        let picker = NSSharingServicePicker(items: items)
        picker.delegate = self
        sharingPicker = picker
        sharedFileURL = items.first as? URL
        // A popover needs a positioning view that is in a window: the toolbar
        // keeps the button's view alive while hidden or in the overflow.
        if let anchor = shareAnchor, anchor.window != nil {
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        } else if let webView {
            // Invoked from the menu in a window without the toolbar button:
            // fall back to where that button would have been.
            let bounds = webView.bounds
            let flipped = webView.isFlipped
            let corner = NSRect(
                x: bounds.maxX - 1,
                y: flipped ? bounds.minY : bounds.maxY - 1,
                width: 1,
                height: 1
            )
            // Whichever edge of that rect faces down on screen.
            picker.show(relativeTo: corner, of: webView, preferredEdge: flipped ? .maxY : .minY)
        } else {
            sharingPicker = nil
            sharedFileURL = nil
            return false
        }
        return true
    }

    // Namespaced: the temp directory is shared per-user, and the sweep deletes
    // by prefix.
    private static let shareDirectoryPrefix = "vmd-share-"
    private static let shareMaxAge: TimeInterval = 3600

    private func discardShareDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// A shared file has to outlive its picker — services read it after the
    /// popover closes — so the leftovers are swept on the next share instead.
    private func sweepStaleShareDirectories() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let now = Date()
        for entry in entries where entry.lastPathComponent.hasPrefix(Self.shareDirectoryPrefix) {
            let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate,
                  now.timeIntervalSince(modified) > Self.shareMaxAge else { continue }
            try? FileManager.default.removeItem(at: entry)
        }
    }
}

extension ViewerModel: NSSharingServicePickerDelegate {
    // nonisolated because the protocol is not annotated for the main actor,
    // even though AppKit only ever calls this there.
    nonisolated func sharingServicePicker(
        _ picker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        // No service means the user dismissed the picker, so nothing is going
        // to read the file we wrote for it.
        let cancelled = service == nil
        // Released one turn later so the chosen service isn't torn down with
        // the picker before it has started.
        Task { @MainActor [weak self] in
            guard let self else { return }
            sharingPicker = nil
            if cancelled, let url = sharedFileURL {
                discardShareDirectory(for: url)
            }
            sharedFileURL = nil
        }
    }
}

extension FocusedValues {
    @Entry var viewerModel: ViewerModel?
}
