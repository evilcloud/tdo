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

        let active = (activePath ?? envActive) ?? config.active ?? dir.appendingPathComponent("active.md").path
        let archive = (archivePath ?? envArchive) ?? config.archive ?? dir.appendingPathComponent("archive.md").path

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
}
