import Foundation
import TDOCore

struct DetailFormatter {
    let styler: Styler
    let wrapper: TextWrap
    let age: AgeLabeler

    func renderOpen(_ t: OpenTask, notes: [String] = []) -> [String] {
        var out: [String] = []
        out.append(styler.stylize("[\(t.uid)] \(t.text)"))
        out.append(styler.stylize("created: \(age.label(createdAt: t.createdAt))"))
        return (notes.map { styler.stylize("note: \($0)") } + out).flatMap { wrapper.wrap($0) }
    }

    func renderArchived(_ a: ArchivedTask, notes: [String] = []) -> [String] {
        var out: [String] = []
        out.append(styler.stylize("[\(a.uid)] \(a.text)"))
        out.append(styler.stylize("created: \(age.label(createdAt: a.createdAt))"))
        out.append(styler.stylize("completed: \(age.label(createdAt: a.completedAt))"))
        out.append(styler.stylize("status: \(a.status)"))
        return (notes.map { styler.stylize("note: \($0)") } + out).flatMap { wrapper.wrap($0) }
    }
}
