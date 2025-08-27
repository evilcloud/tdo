import Foundation

struct Styler {
    let colorize: Bool
    let dimNotes: Bool

    func stylize(_ line: String) -> String {
        guard colorize else { return line }

        if line.hasPrefix("added:") { return Ansi.paint(line, .green) }
        if line.hasPrefix("done:") { return Ansi.paint(line, .green) }
        if line.hasPrefix("undo:") { return Ansi.paint(line, .green) }
        if line.hasPrefix("remove:") { return Ansi.paint(line, .red) }
        if line.hasPrefix("error:") { return Ansi.paint(line, .red, bold: true) }
        if line.hasPrefix("note:") { return dimNotes ? Ansi.paint(line, .dim) : line }

        if isArchiveLine(line) { return Ansi.paint(line, .dim) }

        // Colorize the leading "[UID]"
        if let colored = colorizeUIDBracket(in: line) { return colored }
        return line
    }

    func isArchiveLine(_ line: String) -> Bool {
        line.contains(" @ ") && line.contains(" status: ")
    }

    private func colorizeUIDBracket(in line: String) -> String? {
        guard line.hasPrefix("["),
            let close = line.firstIndex(of: "]"),
            close < line.endIndex
        else { return nil }
        let uidPart = String(line[..<line.index(after: close)])  // incl. closing ]
        let rest = String(line[line.index(after: close)...])
        return Ansi.paint(uidPart, .cyan) + rest
    }
}
