import Foundation

public struct Env {
    public let config: Config
    public let configURL: URL
    public let activeURL: URL
    public let archiveURL: URL
    public let fm = FileManager.default

    public init(activePath: String? = nil, archivePath: String? = nil) throws {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let dir = home.appendingPathComponent(".config/tdo", isDirectory: true)
        try Env.ensureDir(dir)

        let configURL = dir.appendingPathComponent("config")
        self.configURL = configURL
        self.config = try Config.loadOrCreate(at: configURL)

        let envActive = ProcessInfo.processInfo.environment["TDO_FILE"]
        let envArchive = ProcessInfo.processInfo.environment["TDO_ARCHIVE"]

        let defaultActive = dir.appendingPathComponent("active.txt").path
        let defaultArchive = dir.appendingPathComponent("archive.txt").path

        if let cfgActive = config.active, cfgActive != defaultActive,
           fm.fileExists(atPath: defaultActive), !fm.fileExists(atPath: cfgActive) {
            try Env.ensureDir(URL(fileURLWithPath: cfgActive).deletingLastPathComponent())
            try fm.moveItem(atPath: defaultActive, toPath: cfgActive)
        }
        if let cfgArchive = config.archive, cfgArchive != defaultArchive,
           fm.fileExists(atPath: defaultArchive), !fm.fileExists(atPath: cfgArchive) {
            try Env.ensureDir(URL(fileURLWithPath: cfgArchive).deletingLastPathComponent())
            try fm.moveItem(atPath: defaultArchive, toPath: cfgArchive)
        }

        let active = (activePath ?? envActive) ?? config.active ?? defaultActive
        let archive = (archivePath ?? envArchive) ?? config.archive ?? defaultArchive

        self.activeURL = URL(fileURLWithPath: active)
        self.archiveURL = URL(fileURLWithPath: archive)

        try Env.ensureFile(self.activeURL)
        try Env.ensureFile(self.archiveURL)
    }

    public func nowISO8601() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return df.string(from: Date())
    }

    private static func ensureDir(_ url: URL) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: Int16(0o700))])
        } else if !isDir.boolValue {
            throw NSError(
                domain: "Env", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(url.path) exists but is not a directory"])
        }
    }

    private static func ensureFile(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(
                atPath: url.path, contents: Data(),
                attributes: [.posixPermissions: NSNumber(value: Int16(0o600))])
        }
    }

    public func reloading() throws -> Env {
        let old = self.config
        let new = try Config.loadOrCreate(at: configURL)

        let dir = configURL.deletingLastPathComponent()
        let defaultActive = dir.appendingPathComponent("active.txt").path
        let defaultArchive = dir.appendingPathComponent("archive.txt").path

        let prevActive = old.active ?? defaultActive
        let prevArchive = old.archive ?? defaultArchive
        let newActive = new.active ?? defaultActive
        let newArchive = new.archive ?? defaultArchive

        let activeOverride = self.activeURL.path != prevActive ? self.activeURL.path : nil
        let archiveOverride = self.archiveURL.path != prevArchive ? self.archiveURL.path : nil

        if activeOverride == nil && prevActive != newActive,
           fm.fileExists(atPath: prevActive) && !fm.fileExists(atPath: newActive) {
            try Env.ensureDir(URL(fileURLWithPath: newActive).deletingLastPathComponent())
            try fm.moveItem(atPath: prevActive, toPath: newActive)
        }

        if archiveOverride == nil && prevArchive != newArchive,
           fm.fileExists(atPath: prevArchive) && !fm.fileExists(atPath: newArchive) {
            try Env.ensureDir(URL(fileURLWithPath: newArchive).deletingLastPathComponent())
            try fm.moveItem(atPath: prevArchive, toPath: newArchive)
        }

        return try Env(activePath: activeOverride, archivePath: archiveOverride)
    }
}
