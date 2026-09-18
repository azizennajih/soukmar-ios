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
    CategoryConfig(value: "BABY_KIDS", label: "Bébé & Enfants", emoji: "🧸", bg: Color(hex: 0xCCFBF1), fg: Color(hex: 0x0F766E)),
    CategoryConfig(value: "LESSONS_COURSES", label: "Cours & Leçons", emoji: "📚", bg: Color(hex: 0xCFFAFE), fg: Color(hex: 0x0E7490)),
    CategoryConfig(value: "PETS", label: "Animaux", emoji: "🐾", bg: Color(hex: 0xF5E9D9), fg: Color(hex: 0x92603A)),
    CategoryConfig(value: "SPORTS_LEISURE", label: "Sport & Loisirs", emoji: "⚽", bg: Color(hex: 0xE0E7FF), fg: Color(hex: 0x4338CA)),
    CategoryConfig(value: "CARPOOLING", label: "Covoiturage", emoji: "🚕", bg: Color(hex: 0xDBEAFE), fg: Color(hex: 0x1D4ED8)),
    CategoryConfig(value: "TRANSPORT", label: "Transport", emoji: "🚛", bg: Color(hex: 0xFFEDD5), fg: Color(hex: 0xC2410C)),
    CategoryConfig(value: "RENTAL", label: "Location", emoji: "🚙", bg: Color(hex: 0xF3E8FF), fg: Color(hex: 0x7E22CE)),
    CategoryConfig(value: "TICKETS", label: "Billets & Tickets", emoji: "🎫", bg: Color(hex: 0xFEF9C3), fg: Color(hex: 0xA16207)),
    CategoryConfig(value: "GIVEAWAY_SWAP", label: "Dons & Échanges", emoji: "🎁", bg: Color(hex: 0xDCFCE7), fg: Color(hex: 0x15803D)),
    CategoryConfig(value: "MOVING", label: "Déménagement", emoji: "🚚", bg: Color(hex: 0xF5E9D9), fg: Color(hex: 0x92603A)),
    CategoryConfig(value: "OTHER", label: "Autres", emoji: "📦", bg: Color(hex: 0xF1F5F9), fg: Color(hex: 0x475569)),
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

/// Subcategories that opt out of the Neuf/Occasion condition field despite
/// being in an otherwise physical-goods `CONDITION_CATEGORIES` category
/// (e.g. Sport & Loisirs' "Offres d'entraînement" coaching, a service not a
/// good). Mirrors listing.model.ts's/Android's `NO_CONDITION_SUBCATEGORIES`.
let NO_CONDITION_SUBCATEGORIES: Set<String> = ["TRAINING_OFFERS"]

/// Mirrors listing.model.ts's JOB_PROFESSIONS_BY_SECTOR — job profession
/// codes grouped by the Jobs category's INDUSTRY attribute, used to narrow
/// the PROFESSION autocomplete's suggestions once a sector is picked.
let JOB_PROFESSIONS_BY_SECTOR: [String: [String]] = [
    "HEALTHCARE": ["DOCTOR", "DENTIST", "PHARMACIST", "NURSE", "PHYSIOTHERAPIST", "OCCUPATIONAL_THERAPIST", "MIDWIFE", "MEDICAL_ASSISTANT", "PSYCHOLOGIST", "PARAMEDIC", "LAB_TECHNICIAN", "OTHER_HEALTHCARE"],
    "IT": ["COMPUTER_SCIENTIST", "SOFTWARE_DEVELOPER", "WEB_DEVELOPER", "APP_DEVELOPER", "IT_SYSTEM_ADMIN", "NETWORK_ADMIN", "CYBERSECURITY", "DATA_SCIENTIST_AI", "DATABASE_ADMIN", "IT_SUPPORT", "SAP_SPECIALIST", "DEVOPS_CLOUD", "IT_PROJECT_MANAGER"],
    "SKILLED_TRADES": ["ELECTRICIAN", "INSTALLER", "HEATING_SANITARY", "MECHANIC", "AUTO_MECHATRONIC", "LOCKSMITH", "CARPENTER", "ROOF_CARPENTER", "MASON", "PAINTER", "ROOFER", "TILER", "METAL_WORKER", "PLANT_MECHANIC", "INDUSTRIAL_MECHANIC", "MECHATRONICS_TECH", "CNC_SPECIALIST"],
    "CONSTRUCTION": ["CIVIL_ENGINEER", "ARCHITECT", "SITE_MANAGER", "STRUCTURAL_ENGINEER", "SURVEYING", "CIVIL_WORKS", "BUILDING_CONSTRUCTION", "ROAD_CONSTRUCTION", "CONSTRUCTION_HELPER"],
    "OFFICE_ADMIN": ["BUSINESS_CLERK", "CASE_WORKER", "ADMINISTRATION", "RECEPTION", "SECRETARIAT", "ASSISTANT", "HR", "ACCOUNTING", "CONTROLLING", "PURCHASING", "QUALITY_MANAGEMENT"],
    "FINANCE": ["BANKING", "INSURANCE", "TAX_ADVISOR", "AUDITOR", "FINANCIAL_ADVISOR", "CONTROLLER", "ACCOUNTANT", "REAL_ESTATE_FINANCE", "MANAGEMENT_CONSULTING"],
    "SALES": ["SALESPERSON", "RETAIL", "WHOLESALE", "CASHIER", "STORE_MANAGEMENT", "FIELD_SALES", "SALES_REP", "ECOMMERCE", "CUSTOMER_ADVISOR"],
    "LOGISTICS_TRANSPORT": ["TRUCK_DRIVER", "BUS_DRIVER", "TAXI_DRIVER", "COURIER_DRIVER", "WAREHOUSE_WORKER", "ORDER_PICKER", "LOGISTICS", "FREIGHT_FORWARDING", "DISPATCHER", "WAREHOUSE_MANAGEMENT"],
    "HOSPITALITY": ["COOK", "KITCHEN_HELPER", "WAITER", "RESTAURANT_STAFF", "BAKER", "PASTRY_CHEF", "HOTEL", "FRONT_DESK", "HOUSEKEEPING"],
    "EDUCATION": ["TEACHER", "EDUCATOR", "PEDAGOGUE", "PROFESSOR", "LECTURER", "TRAINER", "RESEARCH", "SCIENCE"],
    "LEGAL_SECURITY": ["LAWYER", "NOTARY", "LEGAL_EXPERT", "LEGAL_ASSISTANT", "POLICE", "FIRE_DEPARTMENT", "SECURITY_SERVICE", "JUDICIARY"],
    "MANUFACTURING": ["PRODUCTION_WORKER", "MACHINE_OPERATOR", "PLANT_OPERATOR", "QUALITY_CONTROL", "PRODUCTION_TECHNICIAN", "WELDER", "MANUFACTURING_GENERAL", "FOOD_PRODUCTION", "INDUSTRIAL_MECHANIC"],
    "AGRICULTURE_ENVIRONMENT": ["FARMER", "GARDENER", "FORESTER", "ANIMAL_CARETAKER", "AGRICULTURAL_HELPER", "ENVIRONMENTAL_TECH", "RECYCLING"],
    "MEDIA_DESIGN": ["GRAPHIC_DESIGNER", "WEB_DESIGNER", "PHOTOGRAPHER", "VIDEOGRAPHER", "JOURNALIST", "SOCIAL_MEDIA", "MARKETING", "ADVERTISING", "TRANSLATOR", "INTERPRETER"],
    "BEAUTY_PERSONAL_SERVICES": ["HAIRDRESSER", "BEAUTICIAN", "NAIL_DESIGNER", "FOOT_CARE", "MASSEUR", "CLEANING_STAFF", "HOUSEHOLD_HELP"],
    "CARE_SOCIAL": ["CHILDCARE", "EDUCATOR", "SOCIAL_WORKER", "ELDERLY_CARE", "CARE_WORKER", "DISABILITY_SUPPORT", "FAMILY_SUPPORT"],
    "ENGINEERING_SCIENCE": ["MECHANICAL_ENGINEERING", "ELECTRICAL_ENGINEERING", "CIVIL_ENGINEERING", "INDUSTRIAL_ENGINEERING", "CHEMISTRY", "BIOLOGY", "PHYSICS", "ENVIRONMENTAL_TECH", "MECHATRONICS"],
    "SPORTS": ["FOOTBALL_COACH", "SPORTS_TEACHER", "FITNESS_TRAINER", "PHYSIOTHERAPY", "SPORTS_MANAGEMENT", "SPORTS_CLUB"],
]

/// Flattened, de-duplicated view mirroring JOB_PROFESSION_CODES in listing.model.ts.
let JOB_PROFESSION_CODES: [String] = {
    var seen = Set<String>()
    var result: [String] = []
    for code in JOB_PROFESSIONS_BY_SECTOR.values.flatMap({ $0 }) where seen.insert(code).inserted {
        result.append(code)
    }
    return result
}()

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
