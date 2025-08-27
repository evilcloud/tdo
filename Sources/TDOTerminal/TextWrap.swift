import Foundation

struct TextWrap {
    let width: Int?

    func wrap(_ line: String) -> [String] {
        guard let width, width > 8, line.count > width else { return [line] }

        var result: [String] = []
        var current = line
        while current.count > width {
            let idx = current.index(current.startIndex, offsetBy: width)
            var breakIdx = idx
            if let space = current[..<idx].lastIndex(of: " ") { breakIdx = space }
            let left = String(current[..<breakIdx])
            let right = String(current[current.index(after: breakIdx)...])
            result.append(left)
            current = right
        }
        result.append(current)
        return result
    }
}
