import Foundation

/// Localised city names by app language ("Munich" -> "München", "Vienna" -> "Wien", Moroccan cities in
/// Arabic, ...). The data is the web's `city-names.ts` table (Resources/city-names.txt, one line per city:
/// `Stored name|de|fr|es|it|ar`, an empty slot meaning "same as the stored name") plus the Moroccan
/// Arabic names (Resources/morocco-cities-ar.txt). Cities stay stored and filtered under their one canonical
/// spelling — only the *label* changes, mirroring web's/Android's `cityLabel()`.
enum CityNames {
    private static let columns = ["de", "fr", "es", "it", "ar"]

    private static let labels: [String: [String: String]] = {
        var out: [String: [String: String]] = [:]
        for lang in columns { out[lang] = [:] }
        for line in lines(of: "city-names") {
            let parts = line.components(separatedBy: "|")
            let city = parts[0].trimmingCharacters(in: .whitespaces)
            for (i, lang) in columns.enumerated() where parts.count > i + 1 {
                let label = parts[i + 1].trimmingCharacters(in: .whitespaces)
                if !label.isEmpty && label != city { out[lang]?[city] = label }
            }
        }
        return out
    }()

    private static let moroccoArabic: [String: String] = {
        var out: [String: String] = [:]
        for line in lines(of: "morocco-cities-ar") {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 2 { out[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces) }
        }
        return out
    }()

    private static func lines(of resource: String) -> [String] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }
    }

    static func label(_ city: String, lang: String) -> String? {
        if lang == "ar", let name = moroccoArabic[city] { return name }
        return labels[lang]?[city]
    }
}

/// City display label in the app language; falls back to the stored string for anything not in a dictionary
/// (e.g. free text a user typed). Mirrors listing.model.ts's cityLabel().
func cityLabel(_ city: String, lang: String) -> String {
    city.isEmpty ? city : (CityNames.label(city, lang: lang) ?? city)
}
