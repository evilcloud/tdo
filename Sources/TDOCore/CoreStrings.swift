import Foundation

public enum CoreStrings {
    // MARK: - Generic prefixes
    public static func note(_ message: String) -> String { "note: \(message)" }
    public static func error(_ message: String) -> String { "error: \(message)" }

    // MARK: - Engine top-level
    public static func errorShellOnlyTopLevel() -> String {
        error("'shell' is only valid as a top-level command")
    }
    public static func notePinHandledByMac() -> String {
        note("pin/unpin handled by macOS app")
    }
    public static func noteExitHandledByMac() -> String {
        note("exit handled by macOS app")
    }
    public static func noteConfigHandledExternally() -> String {
        note("config handled externally")
    }

    // MARK: - Engine helpers
    public static func noteAmbiguousPrefix(prefix: String, chosen: String, choices: [String]) -> String {
        note("ambiguous prefix '\(prefix)' → chose \(chosen) among [\(choices.joined(separator: ","))]")
    }
    public static func noteNoTaskMatches(prefix: String) -> String {
        note("no task matches '\(prefix)'")
    }
    public static func noteEmptyTaskText() -> String {
        note("empty task text — nothing added")
    }
    public static func added(uid: String, text: String, count: String) -> String {
        "added: [\(uid)] \(text) · \(count)"
    }
    public static func listItem(uid: String, text: String) -> String {
        "[\(uid)] \(text)"
    }
    public static func archivedItem(uid: String, text: String, completedAt: String, status: String) -> String {
        "[\(uid)] \(text) @ \(completedAt) status: \(status)"
    }
    public static func detailOpen(uid: String, text: String, count: String, createdAt: String) -> [String] {
        ["[\(uid)] \(text) · \(count)", "created: \(createdAt)"]
    }
    public static func detailArchived(uid: String, text: String, count: String, createdAt: String, completedAt: String, status: String) -> [String] {
        [
            "[\(uid)] \(text) · \(count)",
            "created: \(createdAt)",
            "completed: \(completedAt)",
            "status: \(status)",
        ]
    }
    public static func noteNothingToUndo() -> String {
        note("nothing to undo")
    }
    public static func noteCannotUndo(uid: String) -> String {
        note("cannot undo [\(uid)]; already open")
    }
    public static func undo(uid: String, text: String) -> String {
        "undo: [\(uid)] \(text)"
    }
    public static func noteNothingMatched() -> String {
        note("nothing matched")
    }
    public static func done(uid: String, text: String, status: String) -> String {
        "done: [\(uid)] \(text) status: \(status)"
    }
    public static func remove(uid: String, text: String, status: String) -> String {
        "remove: [\(uid)] \(text) status: \(status)"
    }
    public static func noOpenTasksToMarkDone() -> String {
        "no open tasks to mark done"
    }
    public static func countSummary(words: Int, chars: Int, bytes: Int) -> String {
        "\(words)w \(chars)c \(bytes)b"
    }
    public static let statusDone = "done"
    public static let statusDeleted = "deleted"
    public static func fileReadFailed(path: String, error: Error) -> String {
        "Failed to read \(path): \(error)"
    }
    public static func fileAtomicWriteFailed(path: String, error: Error) -> String {
        "Atomic write failed for \(path): \(error)"
    }
    public static func envNotDirectory(path: String) -> String {
        "\(path) exists but is not a directory"
    }

    // MARK: - UID errors
    public static func uidCouldNotGenerate() -> String {
        "could not generate UID"
    }

    // MARK: - UID resolution notes (unprefixed)
    public static func uidNoOpenTaskMatches(_ raw: String) -> String {
        "no open task matches '\(raw)'"
    }
    public static func uidAmbiguousPrefix(_ raw: String, chosen: String, choices: [String]) -> String {
        "ambiguous prefix '\(raw)' → chose \(chosen) among [\(choices.joined(separator: ","))]"
    }

    // MARK: - Age labels
    public static let ageLessThanOneMinute = "< 1m"
    public static func ageMinutes(_ m: Int) -> String { "\(m)m" }
    public static let ageLessThanThirtyMinutes = "< 30m"
    public static let ageLessThanOneHour = "< 1h"
    public static func ageHours(_ h: Int) -> String { "\(h)h" }
    public static let ageMorning = "Morning"
    public static let ageNoon = "Noon"
    public static let ageEvening = "Evening"
    public static let ageYesterday = "Yesterday"
    public static func ageDaysAgo(_ d: Int) -> String { "\(d)d ago" }

    // MARK: - Parser
    public static let noCommand = "no command"
    public static func unknownCommand(_ s: String) -> String { "unknown command: \(s)" }
}

