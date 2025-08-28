import Foundation

enum UIDError: Error, CustomStringConvertible {
    case couldNotGenerate

    var description: String {
        switch self {
        case .couldNotGenerate:
            return CoreStrings.uidCouldNotGenerate()
        }
    }
}

struct UID {
    // Forbids command-like substrings inside generated UIDs.
    static let forbiddenSubstrings: [String] = [
        "DO", "DON",  // do/done
        "REM",  // remove
        "LIS",  // list
        "FIN",  // find
        "FOO",  // foo
    ]

    // MARK: Generation

    static func generate(existing: Set<String>) throws -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for _ in 0..<10000 {
            let uid = String((0..<5).map { _ in letters.randomElement()! })
            if isAllowedFullUID(uid), !existing.contains(uid) {
                return uid
            }
        }
        throw UIDError.couldNotGenerate
    }

    static func isAllowedFullUID(_ uid: String) -> Bool {
        let u = uid.uppercased()
        guard u.count == 5, u.allSatisfy({ $0 >= "A" && $0 <= "Z" }) else { return false }
        for bad in forbiddenSubstrings where u.contains(bad) { return false }
        return true
    }

    // MARK: Parsing / Normalization

    /// Returns uppercase letters-only token if it's a valid UID *prefix* token from CLI;
    /// otherwise returns nil (auto-fix philosophy: silently ignore non-letter garbage).
    static func normalizePrefixToken(_ token: String) -> String? {
        guard token.range(of: #"^[A-Za-z]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return token.uppercased()
    }

    // MARK: Resolution

    /// Resolve a list of UID prefixes against open tasks.
    /// - Exact match wins.
    /// - If multiple candidates share the prefix, pick **newest by createdAt** and emit a note.
    /// - If none match, emit a note.
    static func resolve(prefixes: [String], open: [OpenTask]) -> (
        matches: [OpenTask], notes: [String]
    ) {
        var notes: [String] = []
        var results: [OpenTask] = []

        let openByUID = Dictionary(uniqueKeysWithValues: open.map { ($0.uid, $0) })

        for raw in prefixes {
            let pfx = raw.uppercased()

            if let exact = openByUID[pfx] {
                results.append(exact)
                continue
            }

            let candidates = open.filter { $0.uid.hasPrefix(pfx) }
            if candidates.isEmpty {
                notes.append(CoreStrings.uidNoOpenTaskMatches(raw))
            } else if candidates.count == 1 {
                results.append(candidates[0])
            } else {
                // ambiguous → choose newest by createdAt, note the choice
                let chosen = candidates.max(by: { $0.createdAt < $1.createdAt })!
                notes.append(CoreStrings.uidAmbiguousPrefix(raw, chosen: chosen.uid, choices: candidates.map { $0.uid }))
                results.append(chosen)
            }
        }

        return (results, notes)
    }
}
