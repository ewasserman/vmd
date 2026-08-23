import SwiftUI

struct DocumentView: View {
    let fileURL: URL
    @StateObject private var model = ViewerModel()
    @State private var findText = ""
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        MarkdownWebView(
            fileURL: fileURL,
            model: model,
            showsSource: model.showsSource,
            usesFullWidth: model.usesFullWidth
        )
            .overlay(alignment: .topTrailing) {
                if model.isFindVisible { findBar }
            }
            .focusedSceneValue(\.viewerModel, model)
            .onChange(of: model.isFindVisible) { _, visible in
                findFieldFocused = visible
            }
            .toolbar {
                ToolbarItem {
                    Toggle(isOn: $model.showsSource) {
                        Label("Source", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .toggleStyle(.button)
                    .help("Toggle source view (⇧⌘U)")
                }
                ToolbarItem {
                    Button {
                        model.sharePDF()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .help("Share as PDF")
                    .background(ShareAnchor(model: model))
                }
            }
    }

    /// Registers the Share button's backing view with the model: the share
    /// popover has to point at the button, and SwiftUI doesn't hand it over.
    private struct ShareAnchor: NSViewRepresentable {
        let model: ViewerModel

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            model.shareAnchor = view
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            model.shareAnchor = nsView
        }
    }

    private var findBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find", text: $findText)
                .textFieldStyle(.plain)
                .frame(width: 180)
                .focused($findFieldFocused)
                .onSubmit { model.find(findText) }
            Button {
                model.find(findText, backwards: true)
            } label: {
                Image(systemName: "chevron.up")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            Button {
                model.find(findText)
            } label: {
                Image(systemName: "chevron.down")
            }
            .keyboardShortcut("g", modifiers: .command)
            Button("Done") { model.endFinding() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .buttonStyle(.borderless)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4, y: 2)
        .padding(12)
    }
}
