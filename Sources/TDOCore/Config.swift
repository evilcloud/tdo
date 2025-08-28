import Foundation
#if os(macOS)
import AppKit
#endif

public struct Config: Codable {
    public var transparency: Int
    public var active: String?
    public var archive: String?
    public var pin: Bool

    public init(transparency: Int = 100, active: String? = nil, archive: String? = nil, pin: Bool = false) {
        self.transparency = transparency
        self.active = active
        self.archive = archive
        self.pin = pin
    }

    public static func loadOrCreate(at url: URL) throws -> Config {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            let def = Config()
            try def.save(to: url)
            return def
        }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        return try dec.decode(Config.self, from: data)
    }

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }

    public static func openEditor(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        proc.arguments = [url.path]
        try? proc.run()
        #endif
    }
}
