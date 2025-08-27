import Foundation

public struct OpenTask: Equatable {
    public let uid: String
    public let createdAt: String
    public let text: String

    public init(uid: String, createdAt: String, text: String) {
        self.uid = uid
        self.createdAt = createdAt
        self.text = text
    }

    public var lineEncoded: String {
        "\(uid)|\(createdAt)|\(text)"
    }

    public static func decode(_ line: String) -> OpenTask? {
        let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map {
            String($0)
        }
        guard parts.count == 3 else { return nil }
        return OpenTask(uid: parts[0], createdAt: parts[1], text: parts[2])
    }
}

public struct ArchivedTask: Equatable {
    public let uid: String
    public let createdAt: String
    public let text: String
    public let completedAt: String
    public let status: String

    public init(uid: String, createdAt: String, text: String, completedAt: String, status: String) {
        self.uid = uid
        self.createdAt = createdAt
        self.text = text
        self.completedAt = completedAt
        self.status = status
    }

    public var lineEncoded: String {
        "\(uid)|\(createdAt)|\(text)|\(completedAt)|\(status)"
    }

    public static func decode(_ line: String) -> ArchivedTask? {
        let parts = line.split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false).map {
            String($0)
        }
        guard parts.count == 5 else { return nil }
        return ArchivedTask(
            uid: parts[0], createdAt: parts[1], text: parts[2], completedAt: parts[3],
            status: parts[4])
    }
}
