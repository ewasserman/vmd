import Foundation

let arguments = CommandLine.arguments.dropFirst()

guard let path = arguments.first, arguments.count == 1 else {
    FileHandle.standardError.write(Data("usage: vmd <file.md>\n".utf8))
    exit(64)
}

let url = URL(fileURLWithPath: path)
guard FileManager.default.fileExists(atPath: url.path) else {
    FileHandle.standardError.write(Data("vmd: no such file: \(path)\n".utf8))
    exit(66)
}

// Scaffold: the full implementation will launch the VMD app with this file.
print("vmd scaffold — would open \(url.path)")
