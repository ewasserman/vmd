import Foundation

/// Reads bundled viewer assets (highlight.js, mermaid, KaTeX) from the
/// vmd_VMDApp.bundle directory, for embedding into exported HTML. The app
/// passes its own resource bundle; the CLI passes the installed app's.
public struct AssetStore {
    private let root: URL

    public init(resourceBundleURL: URL) {
        self.root = resourceBundleURL
    }

    func data(_ relativePath: String) -> Data? {
        try? Data(contentsOf: root.appendingPathComponent(relativePath))
    }

    func text(_ relativePath: String) -> String? {
        data(relativePath).map { String(decoding: $0, as: UTF8.self) }
    }
}
