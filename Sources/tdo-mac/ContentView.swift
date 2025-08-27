import AppKit
import SwiftUI
import TDOCore

// Variable-resolution time (no exact timestamps)
private struct AgeLabeler {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let mmmDay: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return df
    }()
    func label(_ createdAt: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let created = Self.iso.date(from: createdAt) else { return "" }
        let seconds = now.timeIntervalSince(created)
        if seconds < 60 { return "< 1m" }

        let minutes = Int(seconds / 60)
        if minutes <= 15 { return "\(minutes)m" }
        if minutes < 30 { return "< 30m" }
        if minutes < 60 { return "< 1h" }

        let hours = Int(seconds / 3600)
        if hours <= 6 { return "\(hours)h" }

        if calendar.isDate(created, inSameDayAs: now) {
            let h = calendar.component(.hour, from: created)
            if (5...11).contains(h) { return "Morning" }
            if (12...13).contains(h) { return "Noon" }
            return "Evening"
        }

        let d0 = calendar.startOfDay(for: now)
        let d1 = calendar.startOfDay(for: created)
        let days = calendar.dateComponents([.day], from: d1, to: d0).day ?? 0
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        return Self.mmmDay.string(from: created)
    }
}

// Regex masker to turn any ISO timestamp in a string into an age label.
private struct TimestampMasker {
    let age = AgeLabeler()
    private static let regex: NSRegularExpression = {
        let p = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+\-]\d{2}:\d{2})"#
        return try! NSRegularExpression(pattern: p, options: [])
    }()
    func mask(_ s: String) -> String {
        let ns = s as NSString
        let matches = Self.regex.matches(
            in: s, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return s }
        var out = s
        for m in matches.reversed() {
            let ts = ns.substring(with: m.range)
            let label = age.label(ts)
            if let r = Range(m.range, in: out) { out.replaceSubrange(r, with: label) }
        }
        return out
    }
}

final class ViewModel: ObservableObject {
    @Published var tasks: [OpenTask] = []
    @Published var command: String = ""
    @Published var status: String? = nil  // one-line feedback
    @Published var selectedIndex: Int? = nil  // keyboard selection

    private let engine: Engine
    private let env: Env
    private let age = AgeLabeler()
    private let mask = TimestampMasker()

    init(engine: Engine, env: Env) {
        self.engine = engine
        self.env = env
        refresh()
    }

    func refresh() {
        do {
            let all = try engine.openTasks(env: env)
            tasks = all.sorted(by: { $0.createdAt > $1.createdAt })
            if selectedIndex.map({ $0 >= tasks.count }) ?? false {
                selectedIndex = tasks.isEmpty ? nil : 0
            }
            if status?.hasPrefix("error:") == true { /* keep error */  } else { status = nil }
        } catch {
            status = "error: \(error)"
        }
    }

    func submit() {
        let line = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            refresh()
            return
        }

        let argv = line.split(separator: " ").map(String.init)
        let cmd: Command
        do { cmd = try Parser.parse(argv: argv) } catch { cmd = .do_(line) }

        // Special handling for show: collapse to a single status line
        if case .show(let pfx) = cmd {
            let (lines, _, _) = engine.execute(cmd, env: env)
            var collapsed = lines
            if let first = lines.first { collapsed[0] = collapseHeader(first) }
            status = collapsed.map { mask.mask($0) }.joined(separator: "  ·  ")
            if let idx = tasks.firstIndex(where: { $0.uid.hasPrefix(pfx.uppercased()) }) {
                selectedIndex = idx
            }
            return
        }

        let (out, mutated, _) = engine.execute(cmd, env: env)
        status = out.first
        if mutated || isListy(cmd) { refresh() }
        if mutated { command = "" }
    }

    func undoLast() {
        let (lines, mutated, _) = engine.execute(.undo, env: env)
        if let first = lines.first { status = first }
        if mutated { refresh() }
    }

    func isListy(_ cmd: Command) -> Bool {
        if case .list = cmd { return true }
        if case .find = cmd { return true }
        return false
    }

    func ageLabel(_ t: OpenTask) -> String { age.label(t.createdAt) }

    // Keyboard selection helpers
    func moveSelection(by delta: Int) {
        guard !tasks.isEmpty else {
            selectedIndex = nil
            return
        }
        let current = selectedIndex ?? 0
        let next = max(0, min(tasks.count - 1, current + delta))
        selectedIndex = next
        let t = tasks[next]
        status = "[\(t.uid)] \(t.text)"
    }

    // Collapse "[UID] very long text..." to a shorter header for the status line
    private func collapseHeader(_ s: String) -> String {
        guard s.hasPrefix("["), let close = s.firstIndex(of: "]") else { return s }
        let uid = String(s[..<s.index(after: close)])  // includes ]
        let rest = s[s.index(after: close)...].trimmingCharacters(in: .whitespaces)
        let width = 56
        if rest.count <= width { return "\(uid) \(rest)" }
        let trunc = rest.prefix(width - 1)
        return "\(uid) \(trunc)…"
    }
}

// NSTextField that captures ↑/↓/PgUp/PgDn via field editor; focuses once on appear
struct CommandField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusOnAppear: Bool = false
    var onSubmit: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void
    var onPageUp: () -> Void
    var onPageDown: () -> Void

    final class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        var parent: CommandField
        var didFocusOnce = false
        init(_ parent: CommandField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool
        {
            switch sel {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onDown()
                return true
            case #selector(NSResponder.pageUp(_:)):
                parent.onPageUp()
                return true
            case #selector(NSResponder.pageDown(_:)):
                parent.onPageDown()
                return true
            default:
                return false
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(string: text)
        tf.isBordered = true
        tf.bezelStyle = .roundedBezel
        tf.focusRingType = .default
        tf.placeholderString = placeholder
        tf.font = NSFont.systemFont(ofSize: 13)
        tf.delegate = context.coordinator

        if focusOnAppear, !context.coordinator.didFocusOnce {
            context.coordinator.didFocusOnce = true
            DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
        // Do NOT refocus here; it causes "one letter overwrites" behavior.
    }
}

struct ContentView: View {
    @StateObject private var vm: ViewModel
    @State private var pageStep: Int = 10

    init(engine: Engine, env: Env) {
        _vm = StateObject(wrappedValue: ViewModel(engine: engine, env: env))
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header + status (single line)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("tdo").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(vm.tasks.count) open").font(.callout).foregroundStyle(.secondary)
                }
                if let s = vm.status {
                    Text(s).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // LIST (simple rows, no separators, soft highlight for selection)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(vm.tasks.enumerated()), id: \.element.uid) { idx, t in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("[\(t.uid)]").font(.system(.callout, design: .monospaced))
                                Text(t.text).lineLimit(1).truncationMode(.tail)
                                Spacer(minLength: 12)
                                Text("· \(vm.ageLabel(t))").foregroundStyle(.secondary).font(
                                    .callout)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                vm.selectedIndex == idx ? Color.accentColor.opacity(0.12) : .clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { vm.selectedIndex = idx }
                            .id(t.uid)
                        }
                    }
                }
                .onChange(of: vm.selectedIndex) { newIdx in
                    guard let newIdx, newIdx >= 0, newIdx < vm.tasks.count else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(vm.tasks[newIdx].uid, anchor: .center)
                    }
                }
            }

            // COMMAND FIELD (captures ⏎, ↑/↓, PgUp/PgDn)
            CommandField(
                text: $vm.command,
                placeholder:
                    "Type a command or just text…  (e.g.  do buy coffee   |   ABC done   |   undo)",
                focusOnAppear: true,
                onSubmit: { vm.submit() },
                onUp: { vm.moveSelection(by: -1) },
                onDown: { vm.moveSelection(by: +1) },
                onPageUp: { vm.moveSelection(by: -pageStep) },
                onPageDown: { vm.moveSelection(by: +pageStep) }
            )
            .frame(height: 26)
            .padding(.top, 8)
        }
        .padding(14)
        // Optional hotkeys from App.swift (if you kept those commands)
        .onReceive(NotificationCenter.default.publisher(for: .tdoUndo)) { _ in vm.undoLast() }
        .onReceive(NotificationCenter.default.publisher(for: .tdoRefresh)) { _ in vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .tdoFocusCommand)) {
            _ in /* could set focus here later */
        }
    }
}
