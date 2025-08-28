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
    static let tdoReloadConfig = Notification.Name("tdoReloadConfig")
}

final class PinObserver: ObservableObject {
    @Published var isPinned: Bool
    private var transparency: Double
    private let configURL: URL

    private var observers: [NSObjectProtocol] = []

    init(config: Config, configURL: URL) {
        self.isPinned = config.pin
        self.transparency = Double(config.transparency) / 100.0
        self.configURL = configURL
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
        observers.append(
            center.addObserver(forName: .tdoReloadConfig, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                if let cfg = try? Config.loadOrCreate(at: self.configURL) {
                    self.isPinned = cfg.pin
                    self.transparency = Double(cfg.transparency) / 100.0
                    self.applyPin()
                }
            }
        )
        DispatchQueue.main.async { self.applyPin() }
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
            window.alphaValue = CGFloat(transparency)
        }
    }
}

@main
struct TDOMacApp: App {
    @StateObject private var pinObserver: PinObserver
    private let env: Env

    init() {
        let env = try! Env()
        self.env = env
        _pinObserver = StateObject(wrappedValue: PinObserver(config: env.config, configURL: env.configURL))
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil) {
                NSApp.applicationIconImage = image
            }
        }
    }

    var body: some Scene {
        WindowGroup(MacStrings.appTitle) {
            ContentView(engine: Engine(), env: env)
                .environmentObject(pinObserver)
                .frame(
                    minWidth: 720, idealWidth: 720, maxWidth: .infinity,
                    minHeight: 460, maxHeight: .infinity)
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(MacStrings.menuQuit) { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: [.command])
            }
            CommandMenu(MacStrings.menuTitle) {
                Button(MacStrings.menuUndoLast) {
                    NotificationCenter.default.post(name: .tdoUndo, object: nil)
                }.keyboardShortcut("z", modifiers: [.command, .shift])
                Button(MacStrings.menuRefresh) {
                    NotificationCenter.default.post(name: .tdoRefresh, object: nil)
                }.keyboardShortcut("r", modifiers: [.command])
                Button(MacStrings.menuFocusCommand) {
                    NotificationCenter.default.post(name: .tdoFocusCommand, object: nil)
                }.keyboardShortcut("l", modifiers: [.command])
                Divider()
                Button(pinObserver.isPinned ? MacStrings.menuUnpinWindow : MacStrings.menuPinWindow) {
                    pinObserver.isPinned.toggle()
                    pinObserver.applyPin()
                }
            }
        }
    }
}
