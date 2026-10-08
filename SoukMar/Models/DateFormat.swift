import Foundation

/// How a country writes a numeric date: order of day/month/year and the separator
/// (DE 05.12.2026, US 12/05/2026, JP 2026/12/05). Mirrors the web's date-format.ts
/// and Android's DateFormat.kt.
enum DatePart { case day, month, year }

struct CountryDateFormat {
    let order: [DatePart]
    let separator: String
}

private let defaultCountryDateFormat = CountryDateFormat(order: [.day, .month, .year], separator: "/")

private final class CountryDateFormatCache {
    static let shared = CountryDateFormatCache()
    private let lock = NSLock()
    private var storage: [String: CountryDateFormat] = [:]

    func get(_ key: String) -> CountryDateFormat? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    func set(_ key: String, _ value: CountryDateFormat) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }
}

/// A locale whose region is `country` — the one with the region's own language when several exist
/// (de_DE, ja_JP, en_US), otherwise the first by identifier.
private func locale(forRegion cc: String) -> Locale? {
    let candidates = Locale.availableIdentifiers
        .map { Locale(identifier: $0) }
        .filter { $0.region?.identifier == cc }
        .sorted { $0.identifier < $1.identifier }
    let own = candidates.first { $0.language.languageCode?.identifier.uppercased() == cc }
    return own ?? candidates.first
}

/// The country's own date convention, read from the platform's locale data — no table to maintain.
func dateFormatForCountry(_ country: String?) -> CountryDateFormat {
    guard let cc = country?.uppercased(), cc.count == 2, cc.allSatisfy({ $0 >= "A" && $0 <= "Z" }) else {
        return defaultCountryDateFormat
    }
    if let cached = CountryDateFormatCache.shared.get(cc) { return cached }

    var format = defaultCountryDateFormat
    if let loc = locale(forRegion: cc),
       let pattern = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: loc) {
        var order: [DatePart] = []
        for ch in pattern {
            let part: DatePart?
            switch ch {
            case "d": part = .day
            case "M", "L": part = .month
            case "y", "u": part = .year
            default: part = nil
            }
            if let part, !order.contains(where: { $0 == part }) { order.append(part) }
        }
        let separator = pattern.first(where: { $0 == "." || $0 == "/" || $0 == "-" }).map { String($0) } ?? "/"
        if order.count == 3 { format = CountryDateFormat(order: order, separator: separator) }
    }
    CountryDateFormatCache.shared.set(cc, format)
    return format
}

/// Numeric date the way the country writes it. Without a year (chat timestamps) the year part is left out.
func formatDateForCountry(_ date: Date, country: String?, withYear: Bool = true) -> String {
    let format = dateFormatForCountry(country)
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let parts: [String] = format.order.compactMap { part in
        switch part {
        case .day: return String(format: "%02d", c.day ?? 1)
        case .month: return String(format: "%02d", c.month ?? 1)
        case .year: return withYear ? String(c.year ?? 1970) : nil
        }
    }
    return parts.joined(separator: format.separator)
}
