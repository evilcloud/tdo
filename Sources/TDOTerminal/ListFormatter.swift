import Foundation
import TDOCore

struct ListFormatter {
    let config: RenderConfig
    let styler: Styler
    let wrapper: TextWrap
    let age: AgeLabeler

    func formatOpenList(_ tasks: [OpenTask], now: Date = Date(), calendar: Calendar = .current)
        -> [String]
    {
        let sorted = tasks.sorted(by: { $0.createdAt > $1.createdAt })
        var rendered: [String] = []

        for t in sorted {
            let badge = age.label(createdAt: t.createdAt, now: now, calendar: calendar)
            let uid = "[\(t.uid)]"
            let body = formatBody(text: t.text, width: config.listTextWidth)
            let line = "\(uid) \(body)  ·  \(badge)"
            let styled = styler.stylize(line)
            rendered.append(contentsOf: wrapper.wrap(styled))
        }
        return rendered
    }

    private func formatBody(text: String, width: Int?) -> String {
        guard let w = width, w > 1 else { return text }

        // pad if short
        if text.count < w { return text + String(repeating: " ", count: w - text.count) }
        if text.count == w { return text }

        // truncate and add a dim ellipsis (doesn't increase visible width)
        let cut = text.index(text.startIndex, offsetBy: w - 1)
        let base = String(text[..<cut])
        let ellipsis = config.colorize ? Ansi.paint("…", .dim) : "…"
        return base + ellipsis
    }

}
