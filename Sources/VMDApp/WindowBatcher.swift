import AppKit

/// Groups document windows opened by a single `vmd` CLI invocation into one
/// tabbed window. The CLI writes a batch manifest before opening the files;
/// the first window of a batch becomes the host, later ones join as tabs.
/// Files opened any other way (Finder, ⌘O) match no manifest and stay
/// standalone windows.
@MainActor
enum WindowBatcher {
    /// Mirrored by the CLI's manifest writer in Sources/vmd/main.swift.
    private struct Manifest: Codable {
        let id: String
        let created: Double
        let paths: [String]
    }

    private final class WeakWindow {
        weak var window: NSWindow?
        init(_ window: NSWindow) { self.window = window }
    }

    private static var hosts: [String: WeakWindow] = [:]
    private static let maxAge: TimeInterval = 20

    static let directory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VMD/batches", isDirectory: true)

    /// Returns true when the window joined an existing batch window as a tab.
    @discardableResult
    static func adopt(_ window: NSWindow, showing fileURL: URL) -> Bool {
        var joinedAsTab = false
        if let batchID = batchID(containing: fileURL) {
            if let host = hosts[batchID]?.window, host.isVisible, host !== window {
                if window.tabGroup !== host.tabGroup {
                    detach(window)
                    host.addTabbedWindow(window, ordered: .above)
                }
                window.makeKeyAndOrderFront(nil)
                joinedAsTab = true
            } else {
                // First window of its batch: it may still have been swept into
                // an unrelated group by AppKit's automatic tabbing (which kicks
                // in whenever an existing window's tab bar is visible).
                detach(window)
                hosts[batchID] = WeakWindow(window)
            }
        } else {
            // Not opened by the CLI (Finder, ⌘O): always a standalone window.
            detach(window)
        }
        // A window that stayed solo shouldn't carry the persisted tab bar.
        if let group = window.tabGroup, group.windows.count == 1, group.isTabBarVisible {
            window.toggleTabBar(nil)
        }
        return joinedAsTab
    }

    private static func batchID(containing fileURL: URL) -> String? {
        let path = fileURL.standardizedFileURL.path
        let now = Date().timeIntervalSince1970
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for entry in entries {
            guard let data = try? Data(contentsOf: entry),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { continue }
            guard now - manifest.created <= maxAge else {
                try? FileManager.default.removeItem(at: entry)
                continue
            }
            if manifest.paths.contains(path) { return manifest.id }
        }
        return nil
    }

    private static func detach(_ window: NSWindow) {
        guard let group = window.tabGroup, group.windows.count > 1 else { return }
        WindowFrameKeeper.withSavingSuppressed {
            group.removeWindow(window)
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + 28, y: window.frame.origin.y - 28))
        }
        window.makeKeyAndOrderFront(nil)
    }
}
