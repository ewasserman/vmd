import SwiftUI

@main
struct VMDApp: App {
    @FocusedValue(\.viewerModel) private var viewerModel

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { configuration in
            if let url = configuration.fileURL {
                DocumentView(fileURL: url)
            } else {
                ContentUnavailableView(
                    "No Document",
                    systemImage: "doc.text",
                    description: Text("Open a Markdown file to view it.")
                )
            }
        }
        .defaultSize(width: 900, height: 1000)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Find…") { viewerModel?.isFindVisible = true }
                    .keyboardShortcut("f")
                    .disabled(viewerModel == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print…") { viewerModel?.printDocument() }
                    .keyboardShortcut("p")
                    .disabled(viewerModel == nil)
            }
        }
    }
}
