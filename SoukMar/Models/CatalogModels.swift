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

/// Major/mid-size Moroccan cities/communes — mirrors Android's
/// ui/model/CatalogModels.kt MOROCCO_CITIES (itself 1:1 from web's
/// listing.model.ts), used as the curated picker list when the centrally
/// selected country is Morocco. iOS had no city list at all before this
/// (unlike Android, which already had this from an earlier phase) — the
/// Arabic-name display map (MOROCCO_CITIES_AR on web/Android) is a
/// separate, deliberately deferred gap (see CLAUDE.md's existing i18n
/// gap list), not needed for the country/currency feature itself.
let MOROCCO_CITIES: [String] = [
    "Casablanca", "Mohammedia", "El Jadida", "Settat", "Berrechid", "Benslimane", "Médiouna", "Nouaceur",
    "Bouskoura", "Dar Bouazza", "Oulad Teima", "Azemmour", "Haouzia", "Sidi Bennour", "Khémis Zemamra", "Oulad Frej",
    "Bir Jdid", "Lqliaa", "Sidi Smail", "Oulad Amrane", "Had Soualem", "Echemmaia", "Sidi Rahhal", "Bouznika",
    "Benhmed", "Oulad Abbou", "Rabat", "Salé", "Kénitra", "Khémisset", "Sidi Kacem", "Sidi Slimane",
    "Sidi Yahia du Gharb", "Lalla Mimouna", "Mechra Bel Ksiri", "Jorf El Melha", "Ouazzane", "Had Kourt", "Aïn Johra", "Tiflet",
    "Rommani", "Maaziz", "Souk el Arbaa", "Moulay Bousselham", "Sidi Allal Tazi", "Arbaoua", "Fès", "Meknès",
    "Taza", "Ifrane", "Azrou", "Moulay Yacoub", "El Hajeb", "Aïn Taoujdate", "Missour", "Boulemane",
    "Guercif", "Sefrou", "Imouzzer Kandar", "Almis Marmoucha", "Aïn Leuh", "Boulmane du Dadès", "Tahla", "Ain Bni Mathar",
    "Itzer", "Rich", "Marrakech", "Safi", "Essaouira", "Kelaa des Sraghna", "Chichaoua", "Youssoufia",
    "Rehamna", "Ben Guerir", "Tamansourt", "Ait Ourir", "Amizmiz", "Tahannaout", "Tahnaout", "Asni",
    "Tighedouine", "Ouarzazate", "Kelaa M'Gouna", "Skoura", "Agdz", "Zagora", "M'Hamid", "Tinzouline",
    "Tamegroute", "Taroudant", "Aoulouz", "Biougra", "Aït Baha", "Massa", "Imintanoute", "Imi n'Tlit",
    "Agadir", "Inezgane", "Aït Melloul", "Tiznit", "Chtouka Aït Baha", "Bensergao", "Drarga", "Tafraout",
    "Sidi Ifni", "Guelmim", "Tan-Tan", "Sidi Bibi", "Sebt Aït Ahmed", "Oulad Dahou", "Aït Iaazza", "Aït Amira",
    "Dcheira El Jihadia", "Tanger", "Tétouan", "Al Hoceïma", "Chefchaouen", "Larache", "Asilah", "Fnideq",
    "Martil", "Mdiq", "Oued Laou", "Bab Berred", "Brikcha", "Jebha", "Targuist", "Imzouren",
    "Bni Bouayach", "Rif", "Ksar El Kébir", "Souk El Arbaa du Rharb", "Zouada", "Ain Defali", "Oujda", "Nador",
    "Berkane", "Taourirt", "Jerada", "Figuig", "Bouarfa", "Aïn Bni Mathar", "Ras El Ma", "Debdou",
    "Aïn Sfa", "Zaïo", "Selouane", "Ben Taïeb", "Saidia", "Aklim", "Boudnib", "Guenfouda",
    "Ahfir", "Garéat Ben Ouali", "Touissit", "Béni Mellal", "Khouribga", "Fquih Ben Salah", "Azilal", "Kasba Tadla",
    "Oued Zem", "Boujad", "El Ksiba", "Demnate", "Aït Attab", "Bzou", "Rahhal", "Souk Sebt Oulad Nemma",
    "El Brouj", "Oulad Ayad", "Afourer", "Bni Ayat", "Timoulilt", "Errachidia", "Tinghir", "Midelt",
    "Er-Rich", "Goulmima", "Erfoud", "Rissani", "Merzouga", "Aoufous", "Arfoud", "Jorf",
    "Ksar Souk", "Alnif", "Ghris", "Tinjdad", "Tinejdad", "Iknioun", "Laâyoune", "Boujdour",
    "Smara", "Tarfaya", "Foum El Oued", "Dakhla", "Assa", "Zag", "Tata", "Akka",
    "Foum Zguid", "Tissint", "Aousserd", "Bir Gandouz", "Ouled Teima", "Aïn Harrouda", "Mansouria", "Aïn Chock",
    "Hay Hassani", "Ben Msik", "Sidi Bernoussi", "Aïn Sebaâ", "Sidi Moumen", "Oulfa", "Bel Air", "Anfa",
    "Maarif", "Gauthier", "Agdal", "Hassan", "Souissi", "Hay Riad", "Yacoub El Mansour", "Temara",
    "Aïn Atiq", "Skhirat", "Harhoura", "Aouinet Torkoz", "Taghazout", "Aglou", "Mirleft", "Legzira",
    "Souss", "Tasila", "Imi Mqorn", "Imsouane", "Tamraght", "Aourir", "Belfaa", "Ait Baamrane",
    "Warzazat", "Tazzarine", "Nkob", "Mhamid El Ghizlane", "Akka Ighane", "Icht", "Bou Izakarn", "Ifrane Anti-Atlas",
    "Aït Herbil", "Souk El Had", "Had Hrara", "Tamzaourt", "Tikki", "Imourane", "Oued Souss", "Tikiouine",
    "Tassila", "Dcheira", "Sebt Gzoula", "Sebt Jahjouh", "Sidi L'Mokhtar", "Jemâa Shaïm", "Abda", "Ounagha",
    "Ida Ougnidif", "Chiadma", "Chemaia", "Lalla Fatna", "Sidi Aïssa Ben Slimane", "Tlat Hanchane", "Oulad Berhil", "Tassaout",
    "Aït Ourirr", "Tnine Chtouka", "Tnine Aït Ourir", "Tnine Sidi Yamani", "Moulay Abdallah", "Moulay Brahim", "Moulay Idriss Zerhoun", "Sidi Harazem",
    "Sidi Bettache", "Sidi Bouknadel", "Sidi Yahia el Gharb", "Sidi Allal Bahraoui", "Sidi Mohamed Ben Abdallah", "Sidi Taibi", "Sidi Yahia Zaer", "Aïn El Aouda",
    "Aïn Cheggag", "Aït Oumghar", "Zaïda", "Mrirt", "Khenifra", "Aït Ishaq", "El Kbab", "Timahdite",
    "Ain Aicha", "Taounate", "Ghafsai", "Rhafsai", "Aïn Mediouna", "Galaz", "Arbala", "Zoumi",
    "Derdara", "Bab Taza", "Dar Chaoui", "Ain Bahja", "Tlat Taghramt", "Ametrasse", "Fifi", "Irherm",
    "Askaoun", "Aït Oujane", "Aït Benhaddou",
]

/// Mirrors listing.model.ts's localeForLang() — used everywhere a UI
/// language code needs to become a Locale for formatting.
func localeForLang(_ lang: String) -> Locale {
    switch lang {
    case "ar": return Locale(identifier: "ar_MA")
    case "en": return Locale(identifier: "en_US")
    case "de": return Locale(identifier: "de_DE")
    case "es": return Locale(identifier: "es_ES")
    case "it": return Locale(identifier: "it_IT")
    default: return Locale(identifier: "fr_FR")
    }
}

/// Mirrors formatPriceParts() in listing.model.ts — splits amount/currency so
/// the currency can be rendered smaller. Any valid ISO 4217 code formats
/// correctly via `NumberFormatter.currency` regardless of currency, now that
/// listings can be denominated in any of ~195 countries' currencies (see
/// CountryModels.swift) — no more hand-rolled MAD-only decimal formatting.
func formatPriceParts(_ price: Double, currency: String = "MAD", lang: String = "fr") -> (String, String) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = localeForLang(lang)
    formatter.currencyCode = currency
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    guard let formatted = formatter.string(from: NSNumber(value: price)) else {
        return ("\(Int(price))", currency)
    }
    // NumberFormatter has no formatToParts() equivalent — split the amount
    // from the currency symbol/code by removing whatever the formatter's own
    // currencySymbol/currencyCode property resolved to for this locale
    // (mirrors Android's formatToCharacterIterator() field-tagging approach,
    // just via string removal since Foundation offers no structured parts API).
    let symbol = formatter.currencySymbol ?? currency
    var amount = formatted
    var currencyLabel = currency
    if formatted.contains(symbol), !symbol.isEmpty {
        amount = formatted.replacingOccurrences(of: symbol, with: "")
        currencyLabel = symbol
    }
    amount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
    return (amount, currencyLabel)
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
