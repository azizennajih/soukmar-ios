import SwiftUI

/// Mirrors soukmar-android's `ui/model/CatalogModels.kt`, which itself mirrors
/// soukmar/src/app/models/listing.model.ts's CATEGORIES/CONDITION_CATEGORIES/
/// HIGHLIGHT_ATTR_CODES. Keep all three in sync when the catalog changes.
struct CategoryConfig: Identifiable, Equatable {
    let value: String
    let label: String
    let emoji: String
    let bg: Color
    let fg: Color
    var id: String { value }
}

let CATEGORIES: [CategoryConfig] = [
    CategoryConfig(value: "VEHICLES", label: "Véhicules", emoji: "🚗", bg: Color(hex: 0xDBEAFE), fg: Color(hex: 0x1D4ED8)),
    CategoryConfig(value: "REAL_ESTATE", label: "Immobilier", emoji: "🏠", bg: Color(hex: 0xDCFCE7), fg: Color(hex: 0x15803D)),
    CategoryConfig(value: "JOBS", label: "Emploi", emoji: "💼", bg: Color(hex: 0xF3E8FF), fg: Color(hex: 0x7E22CE)),
    CategoryConfig(value: "ELECTRONICS", label: "Électronique", emoji: "📱", bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207)),
    CategoryConfig(value: "HOME_GARDEN", label: "Maison & Jardin", emoji: "🌿", bg: Color(hex: 0xD1FAE5), fg: Color(hex: 0x065F46)),
    CategoryConfig(value: "FASHION", label: "Mode", emoji: "👗", bg: Color(hex: 0xFCE7F3), fg: Color(hex: 0xBE185D)),
    CategoryConfig(value: "SERVICES", label: "Services", emoji: "🔧", bg: Color(hex: 0xFFEDD5), fg: Color(hex: 0xC2410C)),
    CategoryConfig(value: "OTHER", label: "Autres", emoji: "📦", bg: Color(hex: 0xF1F5F9), fg: Color(hex: 0x475569)),
    CategoryConfig(value: "BABY_KIDS", label: "Bébé & Enfants", emoji: "🍼", bg: Color(hex: 0xCCFBF1), fg: Color(hex: 0x0F766E)),
    CategoryConfig(value: "PETS", label: "Animaux", emoji: "🐾", bg: Color(hex: 0xF5E9D9), fg: Color(hex: 0x92603A)),
    CategoryConfig(value: "SPORTS_LEISURE", label: "Sport & Loisirs", emoji: "⚽", bg: Color(hex: 0xE0E7FF), fg: Color(hex: 0x4338CA)),
]

func categoryConfig(_ value: String) -> CategoryConfig? {
    CATEGORIES.first { $0.value == value }
}

/// Best-effort display label for a catalog code with no i18n string yet —
/// e.g. "FUEL_TYPE" -> "Fuel type". Mirrors Android's humanizeCode().
func humanizeCode(_ code: String) -> String {
    let lower = code.lowercased().replacingOccurrences(of: "_", with: " ")
    return lower.prefix(1).uppercased() + lower.dropFirst()
}

let CONDITION_CATEGORIES: Set<String> = [
    "VEHICLES", "ELECTRONICS", "HOME_GARDEN", "FASHION", "BABY_KIDS", "SPORTS_LEISURE",
]

let CONDITION_OPTIONS: [(value: String, label: String)] = [
    ("NEW", "Neuf"),
    ("LIKE_NEW", "Comme neuf"),
    ("GOOD", "Bon état"),
    ("FAIR", "État moyen"),
]

let HIGHLIGHT_ATTR_CODES: [String: [String]] = [
    "VEHICLES": ["MILEAGE", "FUEL_TYPE"],
    "ELECTRONICS": ["STORAGE_CAPACITY", "RAM"],
    "REAL_ESTATE": ["LIVING_AREA_SQM", "ROOMS"],
    "FASHION": ["SIZE", "SIZE_EU"],
    "HOME_GARDEN": ["FURNITURE_TYPE"],
]

/// Mirrors formatPriceParts() in listing.model.ts — splits amount/currency so
/// the currency can be rendered smaller.
func formatPriceParts(_ price: Double, currency: String = "MAD") -> (String, String) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.maximumFractionDigits = 0
    let formatted = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
    return (formatted, currency)
}

/// French relative-time label, e.g. "il y a 5 min" — mirrors Android's timeAgo().
func timeAgo(_ isoDate: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var date = formatter.date(from: isoDate)
    if date == nil {
        formatter.formatOptions = [.withInternetDateTime]
        date = formatter.date(from: isoDate)
    }
    guard let date else { return "" }
    let seconds = max(0, Date().timeIntervalSince(date))
    switch seconds {
    case ..<60: return "à l'instant"
    case ..<3600: return "il y a \(Int(seconds / 60)) min"
    case ..<86400: return "il y a \(Int(seconds / 3600)) h"
    case ..<2_592_000: return "il y a \(Int(seconds / 86400)) j"
    default: return "il y a \(Int(seconds / 2_592_000)) mois"
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
