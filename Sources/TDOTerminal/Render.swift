import Foundation
import TDOCore

public struct Renderer {
    public let config: RenderConfig

    private let styler: Styler
    private let wrapper: TextWrap
    private let grouping: Grouping
    private let listFmt: ListFormatter
    private let detailFmt: DetailFormatter
    private let masker: TimestampMasker

    public init(config: RenderConfig = RenderConfig()) {
        self.config = config
        self.styler = Styler(colorize: config.colorize, dimNotes: config.dimNotes)
        self.wrapper = TextWrap(width: config.wrapWidth)

        // One AgeLabeler instance shared by all time-formatting helpers
        let age = AgeLabeler()
        self.masker = TimestampMasker(age: age)

        self.grouping = Grouping(
            styler: styler,
            wrapper: wrapper,
            colorize: config.colorize,
            masker: masker
        )
        self.listFmt = ListFormatter(
            config: config,
            styler: styler,
            wrapper: wrapper,
            age: age
        )
        self.detailFmt = DetailFormatter(
            styler: styler,
            wrapper: wrapper,
            age: age
        )
    }

    // Print with blank lines around the block
    public func printBlock(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        if config.blankLineBeforeBlock { print("") }
        for l in render(lines) { print(l) }
        if config.blankLineAfterBlock { print("") }
    }

    // Raw string rendering (colors, timestamp masking, grouping, wrapping)
    public func render(_ lines: [String]) -> [String] {
        if config.groupFooSections {
            return grouping.groupedFoo(lines)
        } else {
            var out: [String] = []
            for l in lines {
                let normalized = masker.replace(in: l)  // ← variable-resolution time
                let styled = styler.stylize(normalized)
                out.append(contentsOf: wrapper.wrap(styled))
            }
            return out
        }
    }

    // Structured list rendering for open tasks
    public func renderOpenList(
        _ tasks: [OpenTask],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        listFmt.formatOpenList(tasks, now: now, calendar: calendar)
    }

    // Structured detail rendering (used by `show`)
    public func renderDetail(open t: OpenTask, notes: [String] = []) -> [String] {
        detailFmt.renderOpen(t, notes: notes)
    }

    public func renderDetail(archived a: ArchivedTask, notes: [String] = []) -> [String] {
        detailFmt.renderArchived(a, notes: notes)
    }
}
