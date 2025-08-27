import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

public struct RenderConfig {
    public var colorize: Bool
    public var dimNotes: Bool
    public var blankLineBeforeBlock: Bool
    public var blankLineAfterBlock: Bool
    public var groupFooSections: Bool
    public var wrapWidth: Int?  // nil = no wrapping
    public var listTextWidth: Int?  // align age badge column

    public init(
        colorize: Bool? = nil,
        dimNotes: Bool = true,
        blankLineBeforeBlock: Bool = true,
        blankLineAfterBlock: Bool = true,
        groupFooSections: Bool = true,
        wrapWidth: Int? = nil,
        listTextWidth: Int? = nil
    ) {
        if let c = colorize {
            self.colorize = c
        } else {
            self.colorize = (isatty(fileno(stdout)) != 0)
        }
        self.dimNotes = dimNotes
        self.blankLineBeforeBlock = blankLineBeforeBlock
        self.blankLineAfterBlock = blankLineAfterBlock
        self.groupFooSections = groupFooSections
        self.wrapWidth = wrapWidth
        self.listTextWidth = listTextWidth
    }
}
