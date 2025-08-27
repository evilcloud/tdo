import Foundation

/// Rewrites any ISO-8601 timestamps found in a line into variable-resolution labels.
/// Pattern handled: 2000-01-01T00:00:00Z or with timezone offset like +02:00
struct TimestampMasker {
    let age: AgeLabeler

    // yyyy-MM-dd'T'HH:mm:ss(Z or ±HH:MM)
    private static let regex: NSRegularExpression = {
        let p = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+\-]\d{2}:\d{2})"#
        return try! NSRegularExpression(pattern: p, options: [])
    }()

    func replace(in line: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let ns = line as NSString
        let matches = Self.regex.matches(
            in: line, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return line }

        var result = line
        // Replace right-to-left so earlier ranges stay valid.
        for m in matches.reversed() {
            let ts = ns.substring(with: m.range)
            let label = age.label(createdAt: ts, now: now, calendar: calendar)
            if let range = Range(m.range, in: result) {
                result.replaceSubrange(range, with: label)
            }
        }
        return result
    }
}
