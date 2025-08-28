import Foundation

public enum Action { case done, remove }

public enum Command {
    case shell
    case do_(String)
    case list
    case find(String?)
    case foo(String?)
    case undo
    case show(String)  // NEW
    case act([String], Action, String?)
    case pin
    case unpin
    case exit
    case config
}

enum ParseError: Error, CustomStringConvertible {
    case empty
    case unknownCommand(String)
    var description: String {
        switch self {
        case .empty: return "no command"
        case .unknownCommand(let s): return "unknown command: \(s)"
        }
    }
}

public struct Parser {
    public static func parse(argv: [String]) throws -> Command {
        guard !argv.isEmpty else { throw ParseError.empty }
        let first = argv[0].lowercased()

        // explicit commands
        if first == "shell" { return .shell }
        if first == "undo" { return .undo }
        if first == "do" { return .do_(argv.dropFirst().joined(separator: " ").sanitizedText()) }
        if first == "list" { return .list }
        if first == "find" { return .find(argv.dropFirst().joined(separator: " ").nilIfEmpty()) }
        if first == "foo" { return .foo(argv.dropFirst().joined(separator: " ").nilIfEmpty()) }
        if first == "pin" { return .pin }
        if first == "unpin" { return .unpin }
        if first == "exit" { return .exit }
        if first == "config" { return .config }

        // action-first sugar
        if first == "done" || first == "remove" {
            let action: Action = (first == "done") ? .done : .remove
            var ids: [String] = []
            var i = 1
            while i < argv.count, let norm = UID.normalizePrefixToken(argv[i]) {
                ids.append(norm)
                i += 1
            }
            let status = argv.dropFirst(i).joined(separator: " ").nilIfEmpty()
            return .act(ids, action, status)
        }

        // single UID/prefix → show
        if argv.count == 1, let norm = UID.normalizePrefixToken(argv[0]) {
            return .show(norm)
        }

        // UID-first canonical
        var ids: [String] = []
        var idx = 0
        while idx < argv.count {
            let tok = argv[idx]
            let l = tok.lowercased()
            if l == "done" || l == "remove" { break }
            if let norm = UID.normalizePrefixToken(tok) { ids.append(norm) }
            idx += 1
        }
        guard idx < argv.count else { throw ParseError.unknownCommand(argv[0]) }
        let actionTok = argv[idx].lowercased()
        let action: Action = (actionTok == "done") ? .done : .remove
        let status = argv.dropFirst(idx + 1).joined(separator: " ").nilIfEmpty()
        return .act(ids, action, status)
    }
}

extension String {
    fileprivate func nilIfEmpty() -> String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
    fileprivate func sanitizedText() -> String {
        let scalars = unicodeScalars.filter { $0.value >= 32 || $0 == "\t" }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(
            in: .whitespacesAndNewlines)
    }
}
