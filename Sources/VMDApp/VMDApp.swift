import SwiftUI

@main
struct VMDApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { configuration in
            if let url = configuration.fileURL {
                MarkdownWebView(fileURL: url)
            } else {
                ContentUnavailableView(
                    "No Document",
                    systemImage: "doc.text",
                    description: Text("Open a Markdown file to view it.")
                )
            }
        }
        .defaultSize(width: 900, height: 1000)
    }
}
