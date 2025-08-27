import Foundation

struct Grouping {
    let styler: Styler
    let wrapper: TextWrap
    let colorize: Bool
    let masker: TimestampMasker

    func groupedFoo(_ lines: [String]) -> [String] {
        var openSec: [String] = []
        var archSec: [String] = []

        for l in lines {
            if styler.isArchiveLine(l) {
                archSec.append(l)
            } else {
                openSec.append(l)
            }
        }

        var out: [String] = []
        if !openSec.isEmpty {
            for l in openSec {
                let normalized = masker.replace(in: l)
                let styled = styler.stylize(normalized)
                out.append(contentsOf: wrapper.wrap(styled))
            }
        }
        if !archSec.isEmpty {
            if !out.isEmpty { out.append("") }
            let header = colorize ? Ansi.paint("— archive —", .dim) : "— archive —"
            out.append(header)
            for l in archSec {
                let normalized = masker.replace(in: l)
                let styled = styler.stylize(normalized)
                out.append(contentsOf: wrapper.wrap(styled))
            }
        }
        return out
    }
}
