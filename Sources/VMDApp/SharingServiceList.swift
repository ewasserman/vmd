import AppKit

/// The services the stock File ▸ Share submenu would offer for a PDF.
@MainActor
enum SharingServiceList {
    /// A real PDF on disk so enumeration sees the exact type Share sends.
    /// Not under the vmd-share- prefix: ViewerModel sweeps those away.
    private static let placeholder: URL = {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vmd-menu-placeholder", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("placeholder.pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        if let consumer = CGDataConsumer(data: data),
           let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
            context.beginPDFPage(nil)
            context.endPDFPage()
            context.closePDF()
        }
        try? (data as Data).write(to: url)
        return url
    }()

    // sharingServices(forItems:) is deprecated (the warning below is
    // expected), but its replacement (standardShareMenuItem) is an AppKit
    // menu item that cannot live inside SwiftUI commands; this is the only
    // API that yields the list itself.
    static func current() -> [NSSharingService] {
        NSSharingService.sharingServices(forItems: [placeholder])
    }
}
