import Foundation

public enum ExitCode: Int32 {
    case ok = 0
    case userError = 1
    case ioError = 2
    case unexpected = 3
}

public struct Engine {
    public init() {}

    public func execute(_ cmd: Command, env: Env) -> (
        output: [String], mutated: Bool, code: ExitCode
    ) {
        do {
            switch cmd {
            case .shell:
                // REPL is handled by main.swift; treat reaching here as a user-level misuse.
                return ([CoreStrings.errorShellOnlyTopLevel()], false, .userError)

            case .do_(let text):
                return try doAdd(text: text, env: env)

            case .list:
                let lines = try listOpen(env: env)
                return (lines, false, .ok)

            case .find(let q):
                let lines = try findOpen(env: env, query: q)
                return (lines, false, .ok)

            case .foo(let q):
                let lines = try fooAll(env: env, query: q)
                return (lines, false, .ok)

            case .undo:
                return try undoLast(env: env)

            case .show(let pfx):
                return try show(prefix: pfx, env: env)

            case .act(let ids, let action, let status):
                return try perform(ids: ids, action: action, status: status, env: env)

            case .pin, .unpin:
                return ([CoreStrings.notePinHandledByMac()], false, .ok)
            case .exit:
                return ([CoreStrings.noteExitHandledByMac()], false, .ok)
            case .configShow, .configOpen, .configTransparency, .configPin:
                return ([CoreStrings.noteConfigHandledExternally()], false, .ok)
            }
        } catch let e as FileIOError {
            return ([CoreStrings.error("\(e)")], false, .ioError)
        } catch let e as UIDError {
            return ([CoreStrings.error("\(e)")], false, .unexpected)
        } catch let e as ParseError {
            return ([CoreStrings.error(e.description)], false, .userError)
        } catch {
            return ([CoreStrings.error("\(error)")], false, .unexpected)
        }
    }

    // MARK: - Snapshot accessors (no formatting)

    public func openTasks(env: Env) throws -> [OpenTask] {
        try FileIO.readOpen(env.activeURL)
    }

    private func show(prefix: String, env: Env) throws -> (
        output: [String], mutated: Bool, code: ExitCode
    ) {
        let open = try FileIO.readOpen(env.activeURL)
        let arch = try FileIO.readArchive(env.archiveURL)
        var notes: [String] = []

        // Prefer open tasks
        if let exact = open.first(where: { $0.uid == prefix }) {
            return (notes + detail(open: exact), false, .ok)
        }
        let openCands = open.filter { $0.uid.hasPrefix(prefix) }
        if openCands.count == 1 { return (notes + detail(open: openCands[0]), false, .ok) }
        if openCands.count > 1 {
            let chosen = openCands.max(by: { $0.createdAt < $1.createdAt })!
            notes.append(CoreStrings.noteAmbiguousPrefix(prefix: prefix, chosen: chosen.uid, choices: openCands.map { $0.uid }))
            return (notes + detail(open: chosen), false, .ok)
        }

        // Then archive
        if let exactA = arch.first(where: { $0.uid == prefix }) {
            return (notes + detail(archived: exactA), false, .ok)
        }
        let archCands = arch.filter { $0.uid.hasPrefix(prefix) }
        if archCands.isEmpty {
            return ([CoreStrings.noteNoTaskMatches(prefix: prefix)], false, .userError)
        }
        if archCands.count == 1 { return (notes + detail(archived: archCands[0]), false, .ok) }
        let chosenA = archCands.max(by: { $0.completedAt < $1.completedAt })!
        notes.append(CoreStrings.noteAmbiguousPrefix(prefix: prefix, chosen: chosenA.uid, choices: archCands.map { $0.uid }))
        return (notes + detail(archived: chosenA), false, .ok)
    }

    private func detail(open t: OpenTask) -> [String] {
        CoreStrings.detailOpen(uid: t.uid, text: t.text, count: countInfo(t.text), createdAt: t.createdAt)
    }

    private func detail(archived a: ArchivedTask) -> [String] {
        CoreStrings.detailArchived(
            uid: a.uid,
            text: a.text,
            count: countInfo(a.text),
            createdAt: a.createdAt,
            completedAt: a.completedAt,
            status: a.status
        )
    }

    // MARK: - Commands

    private func doAdd(
        text: String,
        env: Env
    ) throws -> (output: [String], mutated: Bool, code: ExitCode) {
        // Reject empty/whitespace-only tasks
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ([CoreStrings.noteEmptyTaskText()], false, .userError)
        }

        var open = try FileIO.readOpen(env.activeURL)
        let archive = try FileIO.readArchive(env.archiveURL)
        let existing = Set(open.map { $0.uid } + archive.map { $0.uid })
        let uid = try UID.generate(existing: existing)
        let created = env.nowISO8601()
        let task = OpenTask(uid: uid, createdAt: created, text: trimmed)
        open.append(task)
        try FileIO.writeOpen(env.activeURL, tasks: open)
        return ([CoreStrings.added(uid: uid, text: trimmed, count: countInfo(trimmed))], true, .ok)
    }

    private func listOpen(env: Env) throws -> [String] {
        let open = try FileIO.readOpen(env.activeURL)
        return open.sorted(by: { $0.createdAt > $1.createdAt }).map { CoreStrings.listItem(uid: $0.uid, text: $0.text) }
    }

    private func findOpen(env: Env, query: String?) throws -> [String] {
        let q = (query ?? "").lowercased()
        if q.isEmpty { return try listOpen(env: env) }
        let open = try FileIO.readOpen(env.activeURL)
        let filtered = open.filter {
            $0.uid.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
        return filtered.sorted(by: { $0.createdAt > $1.createdAt }).map { CoreStrings.listItem(uid: $0.uid, text: $0.text) }
    }

    private func fooAll(env: Env, query: String?) throws -> [String] {
        let q = (query ?? "").lowercased()
        let open = try FileIO.readOpen(env.activeURL)
        let arch = try FileIO.readArchive(env.archiveURL)

        let openFiltered =
            q.isEmpty
            ? open
            : open.filter { $0.uid.lowercased().contains(q) || $0.text.lowercased().contains(q) }
        let archFiltered =
            q.isEmpty
            ? arch
            : arch.filter {
                $0.uid.lowercased().contains(q) || $0.text.lowercased().contains(q)
                    || $0.status.lowercased().contains(q)
            }

        var lines: [String] = []
        lines.append(
            contentsOf: openFiltered.sorted(by: { $0.createdAt > $1.createdAt }).map {
                CoreStrings.listItem(uid: $0.uid, text: $0.text)
            })
        lines.append(
            contentsOf: archFiltered.sorted(by: { $0.completedAt > $1.completedAt }).map {
                CoreStrings.archivedItem(uid: $0.uid, text: $0.text, completedAt: $0.completedAt, status: $0.status)
            })
        return lines
    }

    // Move the last archived task back to open.
    // Emits:
    //   - "undo: [UID] TEXT" on success (mutated = true)
    //   - "note: nothing to undo" if archive is empty (mutated = false)
    //   - "note: cannot undo [UID]; already open" if UID already present in open (mutated = false)
    private func undoLast(env: Env) throws -> (output: [String], mutated: Bool, code: ExitCode) {
        var open = try FileIO.readOpen(env.activeURL)
        var arch = try FileIO.readArchive(env.archiveURL)

        guard let last = arch.last else {
            return ([CoreStrings.noteNothingToUndo()], false, .userError)
        }
        if open.contains(where: { $0.uid == last.uid }) {
            return ([CoreStrings.noteCannotUndo(uid: last.uid)], false, .userError)
        }

        arch.removeLast()
        let restored = OpenTask(uid: last.uid, createdAt: last.createdAt, text: last.text)
        open.append(restored)

        try FileIO.writeOpen(env.activeURL, tasks: open)
        try FileIO.writeArchive(env.archiveURL, tasks: arch)

        return ([CoreStrings.undo(uid: restored.uid, text: restored.text)], true, .ok)
    }

    private func perform(
        ids: [String],
        action: Action,
        status: String?,
        env: Env
    ) throws -> (output: [String], mutated: Bool, code: ExitCode) {
        let open = try FileIO.readOpen(env.activeURL)
        var output: [String] = []

        // Resolution:
        // - If no IDs and action == .done → fallback to newest open task
        // - Else resolve prefixes normally
        let (matches, notes): ([OpenTask], [String]) = {
            if ids.isEmpty && action == .done {
                if let latest = open.max(by: { $0.createdAt < $1.createdAt }) {
                    return ([latest], [])
                } else {
                    return ([], [CoreStrings.noOpenTasksToMarkDone()])
                }
            } else {
                let r = UID.resolve(prefixes: ids, open: open)
                return (r.matches, r.notes)
            }
        }()

        for note in notes { output.append(CoreStrings.note(note)) }

        // Nothing to act on → no mutation
        guard !matches.isEmpty else {
            return (output.isEmpty ? [CoreStrings.noteNothingMatched()] : output, false, .userError)
        }

        let completedAt = env.nowISO8601()
        var toArchive: [ArchivedTask] = []
        var kept: [OpenTask] = []

        let statusText: String = {
            if let s = status, !s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
            return (action == .done) ? CoreStrings.statusDone : CoreStrings.statusDeleted
        }()

        let acted = Set(matches.map { $0.uid })

        for t in open {
            if acted.contains(t.uid) {
                let arch = ArchivedTask(
                    uid: t.uid,
                    createdAt: t.createdAt,
                    text: t.text,
                    completedAt: completedAt,
                    status: statusText
                )
                toArchive.append(arch)
                switch action {
                case .done:
                    output.append(CoreStrings.done(uid: t.uid, text: t.text, status: statusText))
                case .remove:
                    output.append(CoreStrings.remove(uid: t.uid, text: t.text, status: statusText))
                }
            } else {
                kept.append(t)
            }
        }

        try FileIO.writeOpen(env.activeURL, tasks: kept)
        var archAll = try FileIO.readArchive(env.archiveURL)
        archAll.append(contentsOf: toArchive)
        try FileIO.writeArchive(env.archiveURL, tasks: archAll)
        return (output, true, .ok)
    }

    private func countInfo(_ s: String) -> String {
        let words = s.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
        let chars = s.count
        let bytes = s.lengthOfBytes(using: .utf8)
        return CoreStrings.countSummary(words: words, chars: chars, bytes: bytes)
    }

}
