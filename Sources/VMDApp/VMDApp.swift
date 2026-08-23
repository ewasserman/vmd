import SwiftUI
import AppKit
import ObjectiveC

@main
struct VMDApp: App {
    @FocusedValue(\.viewerModel) private var viewerModel

    init() {
        // AppKit adds an automatic File ▸ Share item to document apps that
        // shares the source file; vmd's Share sends the rendered PDF (the
        // submenu below). NSDocumentController's allowsAutomaticShareMenu is
        // the sanctioned opt-out, but DocumentGroup installs its own
        // controller subclass and breaks if the app registers one first — so
        // the getter is overridden on the base class before AppKit consults
        // it. It must run this early: flipping it after the item exists
        // strands the item half-initialized and corrupts its File menu
        // siblings (Open Recent, Revert To).
        let block: @convention(block) (AnyObject) -> Bool = { _ in false }
        class_replaceMethod(
            NSDocumentController.self,
            NSSelectorFromString("allowsAutomaticShareMenu"),
            imp_implementationWithBlock(block),
            "B@:"
        )
    }

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
                Menu {
                    ForEach(SharingServiceList.current(), id: \.menuItemTitle) { service in
                        Button {
                            viewerModel?.sharePDF(via: service)
                        } label: {
                            Label {
                                Text(service.menuItemTitle)
                            } icon: {
                                Image(nsImage: service.image)
                            }
                        }
                    }
                    Divider()
                    Button("More…") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
                        )
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(viewerModel == nil)
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
                Button { viewerModel?.runPageLayout() } label: {
                    Label("Page Setup…", systemImage: "doc")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(viewerModel == nil)
                Button { viewerModel?.printDocument() } label: {
                    Label("Print…", systemImage: "printer")
                }
                .keyboardShortcut("p")
                .disabled(viewerModel == nil)
            }
        }
    }
}
