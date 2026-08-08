import AppKit

let bundleIdentifier = "com.ewasserman.vmd"

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data("vmd: \(message)\n".utf8))
    exit(code)
}

let arguments = CommandLine.arguments.dropFirst()
guard !arguments.isEmpty, !arguments.contains("-h"), !arguments.contains("--help") else {
    FileHandle.standardError.write(Data("usage: vmd <file.md> [more.md ...]\n".utf8))
    exit(64)
}

let urls = arguments.map { URL(fileURLWithPath: $0).standardizedFileURL }
for url in urls where !FileManager.default.fileExists(atPath: url.path) {
    fail("no such file: \(url.path)", code: 66)
}

// Launch Services knows the app once it has been registered; the fallbacks
// cover fresh installs (Homebrew keeps the app in <prefix>/libexec next to
// this binary) before any registration has happened.
func locateApp() -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
        return url
    }
    var candidates: [URL] = []
    if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
        candidates.append(
            executable.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("libexec/VMD.app")
        )
    }
    candidates.append(URL(fileURLWithPath: "/Applications/VMD.app"))
    candidates.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/VMD.app"))
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
}

guard let appURL = locateApp() else {
    fail("VMD.app not found — install it with `make install` or `brew install ewasserman/tap/vmd`", code: 69)
}

// Batch manifest: tells the app these files belong to one invocation so it
// groups them as tabs of a single window (read by the app's WindowBatcher).
let batchDirectory = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("VMD/batches", isDirectory: true)
let batchID = UUID().uuidString
let manifest: [String: Any] = [
    "id": batchID,
    "created": Date().timeIntervalSince1970,
    "paths": urls.map(\.path),
]
try? FileManager.default.createDirectory(at: batchDirectory, withIntermediateDirectories: true)
if let data = try? JSONSerialization.data(withJSONObject: manifest) {
    try? data.write(to: batchDirectory.appendingPathComponent("\(batchID).json"))
}

NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
    if let error {
        fail(error.localizedDescription, code: 70)
    }
    exit(0)
}
dispatchMain()
