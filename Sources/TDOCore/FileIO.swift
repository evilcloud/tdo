import Foundation

enum FileIOError: Error, CustomStringConvertible {
    case atomicWriteFailed(String)
    case readFailed(String)

    var description: String {
        switch self {
        case .atomicWriteFailed(let s), .readFailed(let s):
            return s
        }
    }
}

struct FileIO {
    static func readLines(_ url: URL) throws -> [String] {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw FileIOError.readFailed(CoreStrings.fileReadFailed(path: url.path, error: error))
        }
        guard let s = String(data: data, encoding: .utf8) else { return [] }
        return s.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(
            String.init)
    }

    static func atomicWriteLines(_ url: URL, lines: [String]) throws {
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent(".tmp.\(UUID().uuidString)")
        let content = lines.joined(separator: "\n")
        do {
            try content.write(to: tmp, atomically: true, encoding: .utf8)
            // fsync for extra safety
            let fh = try FileHandle(forUpdating: tmp)
            if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
                try fh.synchronize()
                try fh.close()
            } else {
                fh.synchronizeFile()
                fh.closeFile()
            }
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
        } catch {
            // best effort cleanup
            try? FileManager.default.removeItem(at: tmp)
            throw FileIOError.atomicWriteFailed(CoreStrings.fileAtomicWriteFailed(path: url.path, error: error))
        }
    }

    static func readOpen(_ url: URL) throws -> [OpenTask] {
        try readLines(url).compactMap(OpenTask.decode)
    }

    static func readArchive(_ url: URL) throws -> [ArchivedTask] {
        try readLines(url).compactMap(ArchivedTask.decode)
    }

    static func writeOpen(_ url: URL, tasks: [OpenTask]) throws {
        try atomicWriteLines(url, lines: tasks.map { $0.lineEncoded })
    }

    static func writeArchive(_ url: URL, tasks: [ArchivedTask]) throws {
        try atomicWriteLines(url, lines: tasks.map { $0.lineEncoded })
    }
}
