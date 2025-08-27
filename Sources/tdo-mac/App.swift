import AppKit
import SwiftUI
import TDOCore

extension Notification.Name {
    static let tdoUndo = Notification.Name("tdoUndo")
    static let tdoRefresh = Notification.Name("tdoRefresh")
    static let tdoFocusCommand = Notification.Name("tdoFocusCommand")
}

@main
struct TDOMacApp: App {
    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("tdo") {
            ContentView(engine: Engine(), env: try! Env())
                .frame(
                    minWidth: 720, idealWidth: 720, maxWidth: .infinity,
                    minHeight: 460, maxHeight: .infinity)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit tdo") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: [.command])
            }
            CommandMenu("tdo") {
                Button("Undo Last") {
                    NotificationCenter.default.post(name: .tdoUndo, object: nil)
                }.keyboardShortcut("z", modifiers: [.command, .shift])
                Button("Refresh") {
                    NotificationCenter.default.post(name: .tdoRefresh, object: nil)
                }.keyboardShortcut("r", modifiers: [.command])
                Button("Focus Command") {
                    NotificationCenter.default.post(name: .tdoFocusCommand, object: nil)
                }.keyboardShortcut("l", modifiers: [.command])
            }
        }
    }
}
