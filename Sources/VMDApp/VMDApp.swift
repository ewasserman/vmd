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
            CommandGroup(after: .saveItem) {
                Button("Export as HTML…") { viewerModel?.exportHTML() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(viewerModel == nil)
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") { viewerModel?.isFindVisible = true }
                    .keyboardShortcut("f")
                    .disabled(viewerModel == nil)
            }
            CommandGroup(after: .toolbar) {
                Toggle("Source View", isOn: Binding(
                    get: { viewerModel?.showsSource ?? false },
                    set: { viewerModel?.showsSource = $0 }
                ))
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(viewerModel == nil)
                Toggle("Full Width", isOn: Binding(
                    get: { viewerModel?.usesFullWidth ?? false },
                    set: { viewerModel?.usesFullWidth = $0 }
                ))
                .keyboardShortcut("l", modifiers: [.command, .shift])
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
