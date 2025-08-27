import Foundation

struct AgeLabeler {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let mmmDay: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return df
    }()

    func label(createdAt: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let created = AgeLabeler.iso.date(from: createdAt) else { return "" }
        let seconds = now.timeIntervalSince(created)
        if seconds < 60 { return "< 1m" }

        let minutes = Int(seconds / 60)
        if minutes <= 15 { return "\(minutes)m" }
        if minutes < 30 { return "< 30m" }
        if minutes < 60 { return "< 1h" }

        let hours = Int(seconds / 3600)
        if hours <= 6 { return "\(hours)h" }

        if calendar.isDate(created, inSameDayAs: now) {
            let h = calendar.component(.hour, from: created)
            if (5...11).contains(h) { return "Morning" }
            if (12...13).contains(h) { return "Noon" }
            return "Evening"
        }

        let d0 = calendar.startOfDay(for: now)
        let d1 = calendar.startOfDay(for: created)
        let days = calendar.dateComponents([.day], from: d1, to: d0).day ?? 0
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        return AgeLabeler.mmmDay.string(from: created)
    }
}
