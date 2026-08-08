import AppKit

/// Remembers the frame of the most recently moved or resized document window
/// and gives new windows that same size and position.
@MainActor
enum WindowFrameKeeper {
    private static let defaultsKey = "lastDocumentWindowFrame"
    private static var suppressed = false
    private static var observer: Observer?

    static func installObservers() {
        guard observer == nil else { return }
        let observer = Observer()
        self.observer = observer
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            NotificationCenter.default.addObserver(
                observer, selector: #selector(Observer.windowChanged(_:)), name: name, object: nil
            )
        }
    }

    static func applySavedFrame(to window: NSWindow) {
        guard let saved = UserDefaults.standard.string(forKey: defaultsKey) else { return }
        let frame = NSRectFromString(saved)
        guard frame.width >= 200, frame.height >= 200 else { return }
        withSavingSuppressed { window.setFrame(frame, display: true) }
    }

    /// Wraps programmatic frame changes (applying the saved frame, the
    /// batch detach offset) so they don't overwrite the remembered frame.
    static func withSavingSuppressed(_ body: () -> Void) {
        suppressed = true
        defer { suppressed = false }
        body()
    }

    @MainActor
    private final class Observer: NSObject {
        @objc func windowChanged(_ notification: Notification) {
            guard !WindowFrameKeeper.suppressed,
                  let window = notification.object as? NSWindow,
                  !(window is NSPanel),
                  window.isVisible,
                  window.styleMask.contains(.titled),
                  window.styleMask.contains(.resizable)
            else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: WindowFrameKeeper.defaultsKey)
        }
    }
}
