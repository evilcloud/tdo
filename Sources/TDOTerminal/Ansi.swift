import Foundation

enum AnsiColor { case red, green, cyan, dim }

enum Ansi {
    static func paint(_ s: String, _ c: AnsiColor, bold: Bool = false) -> String {
        let code: String
        switch c {
        case .red: code = bold ? "1;31" : "31"
        case .green: code = bold ? "1;32" : "32"
        case .cyan: code = bold ? "1;36" : "36"
        case .dim: code = "2"
        }
        return "\u{001B}[\(code)m\(s)\u{001B}[0m"
    }
}
