import AppKit
import SwiftUI
import TDOCore

extension Notification.Name {
    static let tdoUndo = Notification.Name("tdoUndo")
    static let tdoRefresh = Notification.Name("tdoRefresh")
    static let tdoFocusCommand = Notification.Name("tdoFocusCommand")
    static let tdoPin = Notification.Name("tdoPin")
    static let tdoUnpin = Notification.Name("tdoUnpin")
    static let tdoExit = Notification.Name("tdoExit")
}

final class PinObserver: ObservableObject {
    @Published var isPinned = false

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = DistributedNotificationCenter.default()
        observers.append(
            center.addObserver(forName: .tdoPin, object: nil, queue: .main) { [weak self] _ in
                self?.isPinned = true
                self?.applyPin()
            }
        )
        observers.append(
            center.addObserver(forName: .tdoUnpin, object: nil, queue: .main) { [weak self] _ in
                self?.isPinned = false
                self?.applyPin()
            }
        )
        observers.append(
            center.addObserver(forName: .tdoExit, object: nil, queue: .main) { _ in
                NSApp.terminate(nil)
            }
        )
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func applyPin() {
        for window in NSApp.windows {
            window.level = isPinned ? .floating : .normal
        }
    }
}

@main
struct TDOMacApp: App {
    @StateObject private var pinObserver = PinObserver()

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil) {
                NSApp.applicationIconImage = image
            }
        }
    }

    var body: some Scene {
        WindowGroup("tdo") {
            ContentView(engine: Engine(), env: try! Env())
                .environmentObject(pinObserver)
                .frame(
                    minWidth: 720, idealWidth: 720, maxWidth: .infinity,
                    minHeight: 460, maxHeight: .infinity)
        }
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
                Divider()
                Button(pinObserver.isPinned ? "Unpin Window" : "Pin Window") {
                    pinObserver.isPinned.toggle()
                    pinObserver.applyPin()
                }
            }
        }
    }
}
