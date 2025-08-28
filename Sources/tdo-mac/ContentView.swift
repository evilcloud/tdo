import AppKit
import SwiftUI
import TDOCore
import TDOTerminal

final class ViewModel: ObservableObject {
    @Published var tasks: [OpenTask] = []
    @Published var lines: [String]? = nil
    @Published var command: String = ""
    @Published var status: String? = nil  // last action / feedback
    @Published var selectedIndex: Int? = nil  // keyboard selection
    @Published var title: String = "tdo"

    private let engine: Engine
    private let env: Env
    private let age = AgeLabeler()
    private let mask: TimestampMasker
    private let renderer: Renderer

    init(engine: Engine, env: Env) {
        self.engine = engine
        self.env = env
        self.mask = TimestampMasker(age: age)
        self.renderer = Renderer(
            config: RenderConfig(
                colorize: false,
                blankLineBeforeBlock: false,
                blankLineAfterBlock: false
            )
        )
        refresh()
    }

    func refresh() {
        do {
            let all = try engine.openTasks(env: env)
            tasks = all.sorted(by: { $0.createdAt > $1.createdAt })
            lines = nil
            title = "tdo"
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

        // Special handling for list to restore open tasks
        if case .list = cmd {
            refresh()
            status = nil
            return
        }

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

        // Special handling for find/foo: render lines and update title
        if case .find(let q) = cmd {
            let (out, _, _) = engine.execute(cmd, env: env)
            lines = renderer.render(out)
            title = "tdo - find" + ((q ?? "").isEmpty ? "" : " [\(q!)]")
            status = nil
            selectedIndex = nil
            command = ""  // clear search field
            return
        }
        if case .foo(let q) = cmd {
            let (out, _, _) = engine.execute(cmd, env: env)
            lines = renderer.render(out)
            title = "tdo - foo" + ((q ?? "").isEmpty ? "" : " [\(q!)]")
            status = nil
            selectedIndex = nil
            command = ""  // clear search field
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
        if case .exit = cmd {
            NSApp.terminate(nil)
            return
        }
#endif

        let (out, mutated, _) = engine.execute(cmd, env: env)
        status = out.first
        if mutated { refresh(); command = "" }
    }

    func undoLast() {
        let (lines, mutated, _) = engine.execute(.undo, env: env)
        if let first = lines.first { status = first }
        if mutated { refresh() }
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
    var onEscape: () -> Void

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
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
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
        tf.isBezeled = false
        tf.focusRingType = .none
        tf.drawsBackground = false
        tf.backgroundColor = .clear
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
            // Status line
            HStack {
                Text(
                    vm.status ?? (
                        vm.lines.map { "\($0.count) results" }
                        ?? "\(vm.tasks.count) open"
                    )
                )
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer()
            }

            // LIST (simple rows, no separators, soft highlight for selection)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let lines = vm.lines {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 15, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
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
                }
                .onChange(of: vm.selectedIndex) { newIdx in
                    guard vm.lines == nil,
                          let newIdx,
                          newIdx >= 0,
                          newIdx < vm.tasks.count else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(vm.tasks[newIdx].uid, anchor: .center)
                    }
                }
            }

            // COMMAND FIELD (captures ⏎, ↑/↓, PgUp/PgDn)
            HStack(spacing: 8) {
                CommandField(
                    text: $vm.command,
                    placeholder:
                        "Type a command or just text…  (e.g.  do buy coffee   |   ABC done   |   undo)",
                    focusOnAppear: true,
                    onSubmit: { vm.submit() },
                    onUp: { vm.moveSelection(by: -1) },
                    onDown: { vm.moveSelection(by: +1) },
                    onPageUp: { vm.moveSelection(by: -pageStep) },
                    onPageDown: { vm.moveSelection(by: +pageStep) },
                    onEscape: {
                        if vm.lines != nil {
                            vm.refresh()
                        }
                    }
                )
                .frame(height: 28)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(vm.title)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    pinObserver.isPinned.toggle()
                    pinObserver.applyPin()
                }) {
                    Image(systemName: pinObserver.isPinned ? "pin.fill" : "pin")
                        .rotationEffect(.degrees(45))
                }
            }
        }
        .onAppear {
            // Blend title bar with the task list area
            if let window = NSApp.windows.first {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor.windowBackgroundColor
                window.title = vm.title
            }
        }
        .onChange(of: vm.title) { newTitle in
            if let window = NSApp.windows.first {
                window.title = newTitle
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
