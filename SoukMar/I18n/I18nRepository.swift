import Foundation

struct LanguageOption {
    let code: String
    let flag: String
    let label: String
}

let SUPPORTED_LANGUAGES: [LanguageOption] = [
    LanguageOption(code: "fr", flag: "🇫🇷", label: "FR"),
    LanguageOption(code: "en", flag: "🇬🇧", label: "EN"),
    LanguageOption(code: "ar", flag: "🇲🇦", label: "عر"),
    LanguageOption(code: "de", flag: "🇩🇪", label: "DE"),
    LanguageOption(code: "es", flag: "🇪🇸", label: "ES"),
    LanguageOption(code: "it", flag: "🇮🇹", label: "IT"),
]

/// Ports the web app's I18nService 1:1 (same as soukmar-android's
/// I18nRepository): same 6 languages, same JSON files (copied verbatim into
/// Resources/i18n/), same dotted-key nested-object lookup, same single-brace
/// {param} interpolation, same fr fallback, same "missing key renders as the
/// raw key" behavior (no per-key language fallback).
///
/// A plain `ObservableObject` singleton rather than a CompositionLocal-style
/// injected value: any SwiftUI view holding `@ObservedObject var i18n =
/// I18nRepository.shared` re-renders automatically when `currentLang`
/// changes, since it's `@Published` — no extra "touch this for
/// recomposition" step needed the way Android's Compose-based `t()` needs.
final class I18nRepository: ObservableObject {
    static let shared = I18nRepository()
    static let defaultLanguage = "fr"
    private static let userDefaultsKey = "soukmar_lang"

    @Published private(set) var currentLang: String

    var isRtl: Bool { currentLang == "ar" }

    private var dictionaries: [String: [String: Any]] = [:]

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
        currentLang = saved.flatMap { code in SUPPORTED_LANGUAGES.contains { $0.code == code } ? code : nil }
            ?? Self.defaultLanguage
        loadDictionaries()
    }

    private func loadDictionaries() {
        for option in SUPPORTED_LANGUAGES {
            guard let url = Bundle.main.url(forResource: option.code, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            dictionaries[option.code] = json
        }
    }

    func setLang(_ code: String) {
        guard code != currentLang, SUPPORTED_LANGUAGES.contains(where: { $0.code == code }) else { return }
        currentLang = code
        UserDefaults.standard.set(code, forKey: Self.userDefaultsKey)
    }

    func t(_ key: String, _ params: [String: String] = [:]) -> String {
        let dict = dictionaries[currentLang] ?? dictionaries[Self.defaultLanguage] ?? [:]
        var node: Any? = dict
        for part in key.split(separator: ".") {
            guard let obj = node as? [String: Any] else { return key }
            node = obj[String(part)]
        }
        guard let raw = node as? String else { return key }
        guard !params.isEmpty else { return raw }
        var result = raw
        for (k, v) in params { result = result.replacingOccurrences(of: "{\(k)}", with: v) }
        return result
    }

    /// For catalog codes (categories/subcategories/EAV attribute+option
    /// codes) that come from the backend dynamically — falls back to the old
    /// humanizeCode() cosmetic transform when no curated translation exists,
    /// rather than showing the raw dotted key like a missing UI-copy key would.
    func tCatalog(_ key: String, code: String) -> String {
        let result = t(key)
        return result == key ? humanizeCode(code) : result
    }

    /// Localized relative-time label built from common.ago/hours/days/minutes
    /// — mirrors Android's timeAgoT(). The "just now"/"months" cases have no
    /// dedicated key in any of the 6 language JSON files (the web app
    /// delegates those to the browser's Intl.RelativeTimeFormat instead), so
    /// those two stay French in every language — same known, documented gap.
    func timeAgoT(_ isoDate: String) -> String {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso8601.date(from: isoDate)
        if date == nil {
            iso8601.formatOptions = [.withInternetDateTime]
            date = iso8601.date(from: isoDate)
        }
        guard let date else { return "" }
        let seconds = max(0, Date().timeIntervalSince(date))
        let ago = t("common.ago")
        switch seconds {
        case ..<60: return "à l'instant"
        case ..<3600: return "\(ago) \(Int(seconds / 60)) \(t("common.minutes"))"
        case ..<86400: return "\(ago) \(Int(seconds / 3600)) \(t("common.hours"))"
        case ..<2_592_000: return "\(ago) \(Int(seconds / 86400)) \(t("common.days"))"
        default: return "\(ago) \(Int(seconds / 2_592_000)) mois"
        }
    }
}
