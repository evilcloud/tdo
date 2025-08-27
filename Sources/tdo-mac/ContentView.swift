import AppKit
import SwiftUI
import TDOCore

final class ViewModel: ObservableObject {
    @Published var tasks: [OpenTask] = []
    @Published var command: String = ""
    @Published var status: String? = nil  // last action / feedback
    @Published var selectedIndex: Int? = nil  // keyboard selection

    private let engine: Engine
    private let env: Env
    private let age = AgeLabeler()
    private let mask: TimestampMasker

    init(engine: Engine, env: Env) {
        self.engine = engine
        self.env = env
        self.mask = TimestampMasker(age: age)
        refresh()
    }

    func refresh() {
        do {
            let all = try engine.openTasks(env: env)
            tasks = all.sorted(by: { $0.createdAt > $1.createdAt })
            if selectedIndex.map({ $0 >= tasks.count }) ?? false {
                selectedIndex = tasks.isEmpty ? nil : 0
            }
        } catch {
            status = "error: \(error)"
        }
    }

    func submit() {
        let line = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty, let idx = selectedIndex, idx < tasks.count {
            command = tasks[idx].uid + " "
            return
        }
        guard !line.isEmpty else { return }

        let argv = line.split(separator: " ").map(String.init)
        let cmd: Command
        do { cmd = try Parser.parse(argv: argv) } catch { cmd = .do_(line) }

        // Special handling for show: collapse to a single status line
        if case .show(let pfx) = cmd {
            let (lines, _, _) = engine.execute(cmd, env: env)
            var collapsed = lines
            if let first = lines.first { collapsed[0] = collapseHeader(first) }
            status = collapsed.map { mask.replace(in: $0) }.joined(separator: "  ·  ")
            if let idx = tasks.firstIndex(where: { $0.uid.hasPrefix(pfx.uppercased()) }) {
                selectedIndex = idx
            }
            return
        }

#if os(macOS)
        if case .pin = cmd {
            DistributedNotificationCenter.default().post(name: .tdoPin, object: nil)
            status = "pinned window"
            command = ""
            return
        }
        if case .unpin = cmd {
            DistributedNotificationCenter.default().post(name: .tdoUnpin, object: nil)
            status = "unpinned window"
            command = ""
            return
        }
#endif

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

    func ageLabel(_ t: OpenTask) -> String { age.label(createdAt: t.createdAt) }

    // Keyboard selection helpers
    func moveSelection(by delta: Int) {
        guard !tasks.isEmpty else {
            selectedIndex = nil
            return
        }
        let current = selectedIndex ?? 0
        let next = max(0, min(tasks.count - 1, current + delta))
        selectTask(next, replaceCommand: false)
    }

    func selectTask(_ idx: Int, replaceCommand: Bool = true) {
        selectedIndex = idx
        let t = tasks[idx]
        status = "[\(t.uid)] \(t.text) · \(countInfo(t.text))"
        if replaceCommand { command = t.uid + " " }
    }

    private func countInfo(_ s: String) -> String {
        let words = s.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
        let chars = s.count
        let bytes = s.lengthOfBytes(using: .utf8)
        return "\(words)w \(chars)c \(bytes)b"
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
        tf.isBordered = false
        tf.focusRingType = .none
        tf.drawsBackground = true
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 6
        // Slightly differentiate command field from the rest of the window
        tf.backgroundColor = NSColor.controlBackgroundColor
        tf.textColor = NSColor.labelColor
        tf.placeholderString = placeholder
        tf.font = NSFont.systemFont(ofSize: 15)
        tf.delegate = context.coordinator

        if focusOnAppear, !context.coordinator.didFocusOnce {
            context.coordinator.didFocusOnce = true
            DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
            }
        }
        nsView.placeholderString = placeholder
    }
}

struct ContentView: View {
    @StateObject private var vm: ViewModel
    @State private var pageStep: Int = 10
    @EnvironmentObject private var pinObserver: PinObserver

    init(engine: Engine, env: Env) {
        _vm = StateObject(wrappedValue: ViewModel(engine: engine, env: env))
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title centered at top
            Text("tdo")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            // Status line
            HStack {
                Text(vm.status ?? "\(vm.tasks.count) open")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer()
            }

            // LIST (simple rows, no separators, soft highlight for selection)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(vm.tasks.enumerated()), id: \.element.uid) { idx, t in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("[\(t.uid)]").font(.system(size: 15, design: .monospaced))
                                Text(t.text).font(.system(size: 15)).lineLimit(1).truncationMode(.tail)
                                Spacer(minLength: 12)
                                Text("· \(vm.ageLabel(t))").foregroundColor(.gray).font(.system(size: 13))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                vm.selectedIndex == idx ? Color.accentColor.opacity(0.12) : .clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { vm.selectTask(idx) }
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
            .frame(height: 30)
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    pinObserver.isPinned.toggle()
                    pinObserver.applyPin()
                }) {
                    Image(systemName: pinObserver.isPinned ? "pin.fill" : "pin")
                        .rotationEffect(.degrees(-45))
                }
            }
        }
        .onAppear {
            // Blend title bar with the task list area
            if let window = NSApp.windows.first {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor.windowBackgroundColor
            }
        }
        // Optional hotkeys from App.swift (if you kept those commands)
        .onReceive(NotificationCenter.default.publisher(for: .tdoUndo)) { _ in vm.undoLast() }
        .onReceive(NotificationCenter.default.publisher(for: .tdoRefresh)) { _ in vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .tdoFocusCommand)) {
            _ in /* could set focus here later */
        }
    }
}
