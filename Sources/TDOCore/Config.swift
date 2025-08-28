import Foundation
#if os(macOS)
import AppKit
#endif

public struct Config: Equatable {
    public var transparency: Int
    public var active: String?
    public var archive: String?
    public var cliEditor: String?
    public var macEditor: String?
    public var pin: Bool

    public init(
        transparency: Int = 100,
        active: String? = nil,
        archive: String? = nil,
        cliEditor: String? = nil,
        macEditor: String? = nil,
        pin: Bool = false
    ) {
        self.transparency = transparency
        self.active = active
        self.archive = archive
        self.cliEditor = cliEditor
        self.macEditor = macEditor
        self.pin = pin
    }

    public static func loadOrCreate(at url: URL) throws -> Config {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: url.path) {
            let def = Config(
                active: dir.appendingPathComponent("active.txt").path,
                archive: dir.appendingPathComponent("archive.txt").path
            )
            try def.save(to: url)
            return def
        }

        let text = try String(contentsOf: url, encoding: .utf8)
        return parse(text: text, baseDir: dir)
    }

    public func save(to url: URL) throws {
        var lines: [String] = []
        lines.append("# tdo configuration")
        lines.append("# window transparency percentage (0-100)")
        lines.append("transparency = \(transparency)")
        lines.append("")
        lines.append("# locations of task files")
        lines.append("active = \(active ?? "")")
        lines.append("archive = \(archive ?? "")")
        lines.append("")
        lines.append("# preferred text editors")
        lines.append("cli-editor = \(cliEditor ?? "")")
        lines.append("mac-editor = \(macEditor ?? "")")
        lines.append("")
        lines.append("# default pin state (true/false)")
        lines.append("pin = \(pin ? "true" : "false")")
        let data = lines.joined(separator: "\n").data(using: .utf8)!
        try data.write(to: url)
    }

    private static func parse(text: String, baseDir: URL) -> Config {
        var cfg = Config(
            active: baseDir.appendingPathComponent("active.txt").path,
            archive: baseDir.appendingPathComponent("archive.txt").path
        )
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "transparency":
                if let v = Int(value) { cfg.transparency = v }
            case "active":
                cfg.active = value.isEmpty ? nil : value
            case "archive":
                cfg.archive = value.isEmpty ? nil : value
            case "cli-editor":
                cfg.cliEditor = value.isEmpty ? nil : value
            case "mac-editor":
                cfg.macEditor = value.isEmpty ? nil : value
            case "pin":
                cfg.pin = (value.lowercased() == "true")
            default:
                break
            }
        }
        return cfg
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
