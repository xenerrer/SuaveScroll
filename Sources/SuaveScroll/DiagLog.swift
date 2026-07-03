import Foundation

/// Appends diagnostic lines to ~/Library/Logs/SuaveScroll.log (and mirrors to
/// NSLog). File logging is used because unified-log messages from unsigned
/// apps are often redacted, which makes user bug reports impossible.
enum DiagLog {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("SuaveScroll.log")
    }()

    private static let queue = DispatchQueue(label: "com.lucasschoenherr.suavescroll.log", qos: .utility)
    private static let formatter = ISO8601DateFormatter()

    static func write(_ message: String) {
        NSLog("SuaveScroll: %@", message)
        queue.async {
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
