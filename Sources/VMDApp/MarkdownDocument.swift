import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// Read-only document; the webview renders from disk via the vmd: scheme,
/// so this only exists to drive DocumentGroup (open panel, recents, Finder).
struct MarkdownDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.markdownDocument, .plainText]

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isRegularFile else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.featureUnsupported)
    }
}
