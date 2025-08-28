import Foundation

/// Central repository of macOS UI strings for tdo.
/// Update the values here to change copy throughout the mac app.
/// To provide translations, add a `Localizable.strings` file with the same
/// keys as the strings below.
enum MacStrings {
    // MARK: - App and window titles
    static let appTitle = NSLocalizedString("tdo", comment: "Main app title")
    static let findTitlePrefix = NSLocalizedString("tdo - find", comment: "Window title prefix for find results")
    static let fooTitlePrefix = NSLocalizedString("tdo - foo", comment: "Window title prefix for foo results")
    static let configTitle = NSLocalizedString("tdo - config", comment: "Window title for config view")

    // MARK: - Menus and toolbar
    static let menuTitle = NSLocalizedString("tdo", comment: "Command menu title")
    static let menuQuit = NSLocalizedString("Quit tdo", comment: "Quit menu item")
    static let menuUndoLast = NSLocalizedString("Undo Last", comment: "Undo last menu item")
    static let menuRefresh = NSLocalizedString("Refresh", comment: "Refresh menu item")
    static let menuFocusCommand = NSLocalizedString("Focus Command", comment: "Focus command menu item")
    static let menuPinWindow = NSLocalizedString("Pin Window", comment: "Pin window menu item")
    static let menuUnpinWindow = NSLocalizedString("Unpin Window", comment: "Unpin window menu item")

    // MARK: - Status messages
    static let statusPinnedWindow = NSLocalizedString("pinned window", comment: "Status when window pinned")
    static let statusUnpinnedWindow = NSLocalizedString("unpinned window", comment: "Status when window unpinned")
    static let statusPinOn = NSLocalizedString("pin on", comment: "Status when pin config enabled")
    static let statusPinOff = NSLocalizedString("pin off", comment: "Status when pin config disabled")
    static let statusSetTransparencyFormat = NSLocalizedString("set transparency to %d", comment: "Format for transparency change")

    // MARK: - Errors
    static let errorFormat = NSLocalizedString("error: %@", comment: "Generic error message with description")
    static var errorPrefix: String {
        errorFormat.components(separatedBy: "%@").first?.trimmingCharacters(in: .whitespaces) ?? "error:"
    }

    // MARK: - Placeholder and counts
    static let commandPlaceholder = NSLocalizedString(
        "Type a command or just text…  (e.g.  do buy coffee   |   ABC done   |   undo)",
        comment: "Placeholder for the command input"
    )
    static let resultsFormat = NSLocalizedString("%d results", comment: "Format for results count")
    static let openFormat = NSLocalizedString("%d open", comment: "Format for open tasks count")

    // MARK: - Helpers
    static func setTransparency(_ value: Int) -> String {
        String(format: statusSetTransparencyFormat, value)
    }
    static func results(_ count: Int) -> String {
        String(format: resultsFormat, count)
    }
    static func openCount(_ count: Int) -> String {
        String(format: openFormat, count)
    }
    static func error(_ error: Error) -> String {
        String(format: errorFormat, String(describing: error))
    }
}

