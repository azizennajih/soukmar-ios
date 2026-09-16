import Foundation

/// Mirrors soukmar/src/app/models/dial-codes.ts (and soukmar-android's
/// ui/model/DialCodes.kt) — keep in sync when the web list changes.
/// `primary` marks the preferred country for a dial code shared by several
/// countries (NANP "+1", or "+7" for Russia/Kazakhstan).
///
/// Known gap vs. web (same gap Android accepted): the web app also ships an
/// Arabic name map so Arabic-language users see localized country names —
/// porting that ~196-entry translation table was judged not worth the size.
/// Arabic falls back to the French `name` here, same as Android.
struct DialCode: Identifiable {
    let iso: String
    let name: String
    let dialCode: String
    var primary: Bool = false
    var id: String { iso }
}

let DIAL_CODES: [DialCode] = [
    DialCode(iso: "MA", name: "Maroc", dialCode: "+212"),
    DialCode(iso: "ZA", name: "Afrique du Sud", dialCode: "+27"),
    DialCode(iso: "AL", name: "Albanie", dialCode: "+355"),
    DialCode(iso: "DZ", name: "Algérie", dialCode: "+213"),
    DialCode(iso: "DE", name: "Allemagne", dialCode: "+49"),
    DialCode(iso: "AD", name: "Andorre", dialCode: "+376"),
    DialCode(iso: "AO", name: "Angola", dialCode: "+244"),
    DialCode(iso: "AG", name: "Antigua-et-Barbuda", dialCode: "+1"),
    DialCode(iso: "SA", name: "Arabie saoudite", dialCode: "+966"),
    DialCode(iso: "AR", name: "Argentine", dialCode: "+54"),
    DialCode(iso: "AM", name: "Arménie", dialCode: "+374"),
    DialCode(iso: "AU", name: "Australie", dialCode: "+61"),
    DialCode(iso: "AT", name: "Autriche", dialCode: "+43"),
    DialCode(iso: "AZ", name: "Azerbaïdjan", dialCode: "+994"),
    DialCode(iso: "BS", name: "Bahamas", dialCode: "+1"),
    DialCode(iso: "BH", name: "Bahreïn", dialCode: "+973"),
    DialCode(iso: "BD", name: "Bangladesh", dialCode: "+880"),
    DialCode(iso: "BB", name: "Barbade", dialCode: "+1"),
    DialCode(iso: "BE", name: "Belgique", dialCode: "+32"),
    DialCode(iso: "BZ", name: "Belize", dialCode: "+501"),
    DialCode(iso: "BJ", name: "Bénin", dialCode: "+229"),
    DialCode(iso: "BT", name: "Bhoutan", dialCode: "+975"),
    DialCode(iso: "BY", name: "Biélorussie", dialCode: "+375"),
    DialCode(iso: "MM", name: "Birmanie", dialCode: "+95"),
    DialCode(iso: "BO", name: "Bolivie", dialCode: "+591"),
    DialCode(iso: "BA", name: "Bosnie-Herzégovine", dialCode: "+387"),
    DialCode(iso: "BW", name: "Botswana", dialCode: "+267"),
    DialCode(iso: "BR", name: "Brésil", dialCode: "+55"),
    DialCode(iso: "BN", name: "Brunei", dialCode: "+673"),
    DialCode(iso: "BG", name: "Bulgarie", dialCode: "+359"),
    DialCode(iso: "BF", name: "Burkina Faso", dialCode: "+226"),
    DialCode(iso: "BI", name: "Burundi", dialCode: "+257"),
    DialCode(iso: "KH", name: "Cambodge", dialCode: "+855"),
    DialCode(iso: "CM", name: "Cameroun", dialCode: "+237"),
    DialCode(iso: "CA", name: "Canada", dialCode: "+1"),
    DialCode(iso: "CV", name: "Cap-Vert", dialCode: "+238"),
    DialCode(iso: "CF", name: "République centrafricaine", dialCode: "+236"),
    DialCode(iso: "CL", name: "Chili", dialCode: "+56"),
    DialCode(iso: "CN", name: "Chine", dialCode: "+86"),
    DialCode(iso: "CY", name: "Chypre", dialCode: "+357"),
    DialCode(iso: "CO", name: "Colombie", dialCode: "+57"),
    DialCode(iso: "KM", name: "Comores", dialCode: "+269"),
    DialCode(iso: "CG", name: "Congo-Brazzaville", dialCode: "+242"),
    DialCode(iso: "CD", name: "Congo-Kinshasa", dialCode: "+243"),
    DialCode(iso: "KR", name: "Corée du Sud", dialCode: "+82"),
    DialCode(iso: "KP", name: "Corée du Nord", dialCode: "+850"),
    DialCode(iso: "CR", name: "Costa Rica", dialCode: "+506"),
    DialCode(iso: "CI", name: "Côte d'Ivoire", dialCode: "+225"),
    DialCode(iso: "HR", name: "Croatie", dialCode: "+385"),
    DialCode(iso: "CU", name: "Cuba", dialCode: "+53"),
    DialCode(iso: "DK", name: "Danemark", dialCode: "+45"),
    DialCode(iso: "DJ", name: "Djibouti", dialCode: "+253"),
    DialCode(iso: "DM", name: "Dominique", dialCode: "+1"),
    DialCode(iso: "EG", name: "Égypte", dialCode: "+20"),
    DialCode(iso: "AE", name: "Émirats arabes unis", dialCode: "+971"),
    DialCode(iso: "EC", name: "Équateur", dialCode: "+593"),
    DialCode(iso: "ER", name: "Érythrée", dialCode: "+291"),
    DialCode(iso: "ES", name: "Espagne", dialCode: "+34"),
    DialCode(iso: "EE", name: "Estonie", dialCode: "+372"),
    DialCode(iso: "SZ", name: "Eswatini", dialCode: "+268"),
    DialCode(iso: "US", name: "États-Unis", dialCode: "+1", primary: true),
    DialCode(iso: "ET", name: "Éthiopie", dialCode: "+251"),
    DialCode(iso: "FJ", name: "Fidji", dialCode: "+679"),
    DialCode(iso: "FI", name: "Finlande", dialCode: "+358"),
    DialCode(iso: "FR", name: "France", dialCode: "+33"),
    DialCode(iso: "GA", name: "Gabon", dialCode: "+241"),
    DialCode(iso: "GM", name: "Gambie", dialCode: "+220"),
    DialCode(iso: "GE", name: "Géorgie", dialCode: "+995"),
    DialCode(iso: "GH", name: "Ghana", dialCode: "+233"),
    DialCode(iso: "GR", name: "Grèce", dialCode: "+30"),
    DialCode(iso: "GD", name: "Grenade", dialCode: "+1"),
    DialCode(iso: "GT", name: "Guatemala", dialCode: "+502"),
    DialCode(iso: "GN", name: "Guinée", dialCode: "+224"),
    DialCode(iso: "GQ", name: "Guinée équatoriale", dialCode: "+240"),
    DialCode(iso: "GW", name: "Guinée-Bissau", dialCode: "+245"),
    DialCode(iso: "GY", name: "Guyana", dialCode: "+592"),
    DialCode(iso: "HT", name: "Haïti", dialCode: "+509"),
    DialCode(iso: "HN", name: "Honduras", dialCode: "+504"),
    DialCode(iso: "HK", name: "Hong Kong", dialCode: "+852"),
    DialCode(iso: "HU", name: "Hongrie", dialCode: "+36"),
    DialCode(iso: "IN", name: "Inde", dialCode: "+91"),
    DialCode(iso: "ID", name: "Indonésie", dialCode: "+62"),
    DialCode(iso: "IQ", name: "Irak", dialCode: "+964"),
    DialCode(iso: "IR", name: "Iran", dialCode: "+98"),
    DialCode(iso: "IE", name: "Irlande", dialCode: "+353"),
    DialCode(iso: "IS", name: "Islande", dialCode: "+354"),
    DialCode(iso: "IL", name: "Israël", dialCode: "+972"),
    DialCode(iso: "IT", name: "Italie", dialCode: "+39"),
    DialCode(iso: "JM", name: "Jamaïque", dialCode: "+1"),
    DialCode(iso: "JP", name: "Japon", dialCode: "+81"),
    DialCode(iso: "JO", name: "Jordanie", dialCode: "+962"),
    DialCode(iso: "KZ", name: "Kazakhstan", dialCode: "+7", primary: true),
    DialCode(iso: "KE", name: "Kenya", dialCode: "+254"),
    DialCode(iso: "KG", name: "Kirghizistan", dialCode: "+996"),
    DialCode(iso: "KI", name: "Kiribati", dialCode: "+686"),
    DialCode(iso: "XK", name: "Kosovo", dialCode: "+383"),
    DialCode(iso: "KW", name: "Koweït", dialCode: "+965"),
    DialCode(iso: "LA", name: "Laos", dialCode: "+856"),
    DialCode(iso: "LS", name: "Lesotho", dialCode: "+266"),
    DialCode(iso: "LV", name: "Lettonie", dialCode: "+371"),
    DialCode(iso: "LB", name: "Liban", dialCode: "+961"),
    DialCode(iso: "LR", name: "Liberia", dialCode: "+231"),
    DialCode(iso: "LY", name: "Libye", dialCode: "+218"),
    DialCode(iso: "LI", name: "Liechtenstein", dialCode: "+423"),
    DialCode(iso: "LT", name: "Lituanie", dialCode: "+370"),
    DialCode(iso: "LU", name: "Luxembourg", dialCode: "+352"),
    DialCode(iso: "MO", name: "Macao", dialCode: "+853"),
    DialCode(iso: "MK", name: "Macédoine du Nord", dialCode: "+389"),
    DialCode(iso: "MG", name: "Madagascar", dialCode: "+261"),
    DialCode(iso: "MY", name: "Malaisie", dialCode: "+60"),
    DialCode(iso: "MW", name: "Malawi", dialCode: "+265"),
    DialCode(iso: "MV", name: "Maldives", dialCode: "+960"),
    DialCode(iso: "ML", name: "Mali", dialCode: "+223"),
    DialCode(iso: "MT", name: "Malte", dialCode: "+356"),
    DialCode(iso: "MU", name: "Maurice", dialCode: "+230"),
    DialCode(iso: "MR", name: "Mauritanie", dialCode: "+222"),
    DialCode(iso: "MX", name: "Mexique", dialCode: "+52"),
    DialCode(iso: "FM", name: "Micronésie", dialCode: "+691"),
    DialCode(iso: "MD", name: "Moldavie", dialCode: "+373"),
    DialCode(iso: "MC", name: "Monaco", dialCode: "+377"),
    DialCode(iso: "MN", name: "Mongolie", dialCode: "+976"),
    DialCode(iso: "ME", name: "Monténégro", dialCode: "+382"),
    DialCode(iso: "MZ", name: "Mozambique", dialCode: "+258"),
    DialCode(iso: "NA", name: "Namibie", dialCode: "+264"),
    DialCode(iso: "NR", name: "Nauru", dialCode: "+674"),
    DialCode(iso: "NP", name: "Népal", dialCode: "+977"),
    DialCode(iso: "NI", name: "Nicaragua", dialCode: "+505"),
    DialCode(iso: "NE", name: "Niger", dialCode: "+227"),
    DialCode(iso: "NG", name: "Nigeria", dialCode: "+234"),
    DialCode(iso: "NO", name: "Norvège", dialCode: "+47"),
    DialCode(iso: "NZ", name: "Nouvelle-Zélande", dialCode: "+64"),
    DialCode(iso: "OM", name: "Oman", dialCode: "+968"),
    DialCode(iso: "UG", name: "Ouganda", dialCode: "+256"),
    DialCode(iso: "UZ", name: "Ouzbékistan", dialCode: "+998"),
    DialCode(iso: "PK", name: "Pakistan", dialCode: "+92"),
    DialCode(iso: "PW", name: "Palaos", dialCode: "+680"),
    DialCode(iso: "PS", name: "Palestine", dialCode: "+970"),
    DialCode(iso: "PA", name: "Panama", dialCode: "+507"),
    DialCode(iso: "PG", name: "Papouasie-Nouvelle-Guinée", dialCode: "+675"),
    DialCode(iso: "PY", name: "Paraguay", dialCode: "+595"),
    DialCode(iso: "NL", name: "Pays-Bas", dialCode: "+31"),
    DialCode(iso: "PE", name: "Pérou", dialCode: "+51"),
    DialCode(iso: "PH", name: "Philippines", dialCode: "+63"),
    DialCode(iso: "PL", name: "Pologne", dialCode: "+48"),
    DialCode(iso: "PT", name: "Portugal", dialCode: "+351"),
    DialCode(iso: "QA", name: "Qatar", dialCode: "+974"),
    DialCode(iso: "RO", name: "Roumanie", dialCode: "+40"),
    DialCode(iso: "GB", name: "Royaume-Uni", dialCode: "+44"),
    DialCode(iso: "RU", name: "Russie", dialCode: "+7", primary: true),
    DialCode(iso: "RW", name: "Rwanda", dialCode: "+250"),
    DialCode(iso: "KN", name: "Saint-Christophe-et-Niévès", dialCode: "+1"),
    DialCode(iso: "SM", name: "Saint-Marin", dialCode: "+378"),
    DialCode(iso: "VC", name: "Saint-Vincent-et-les-Grenadines", dialCode: "+1"),
    DialCode(iso: "LC", name: "Sainte-Lucie", dialCode: "+1"),
    DialCode(iso: "SB", name: "Salomon (Îles)", dialCode: "+677"),
    DialCode(iso: "SV", name: "Salvador", dialCode: "+503"),
    DialCode(iso: "WS", name: "Samoa", dialCode: "+685"),
    DialCode(iso: "ST", name: "Sao Tomé-et-Principe", dialCode: "+239"),
    DialCode(iso: "SN", name: "Sénégal", dialCode: "+221"),
    DialCode(iso: "RS", name: "Serbie", dialCode: "+381"),
    DialCode(iso: "SC", name: "Seychelles", dialCode: "+248"),
    DialCode(iso: "SL", name: "Sierra Leone", dialCode: "+232"),
    DialCode(iso: "SG", name: "Singapour", dialCode: "+65"),
    DialCode(iso: "SK", name: "Slovaquie", dialCode: "+421"),
    DialCode(iso: "SI", name: "Slovénie", dialCode: "+386"),
    DialCode(iso: "SO", name: "Somalie", dialCode: "+252"),
    DialCode(iso: "SD", name: "Soudan", dialCode: "+249"),
    DialCode(iso: "SS", name: "Soudan du Sud", dialCode: "+211"),
    DialCode(iso: "LK", name: "Sri Lanka", dialCode: "+94"),
    DialCode(iso: "SE", name: "Suède", dialCode: "+46"),
    DialCode(iso: "CH", name: "Suisse", dialCode: "+41"),
    DialCode(iso: "SR", name: "Suriname", dialCode: "+597"),
    DialCode(iso: "SY", name: "Syrie", dialCode: "+963"),
    DialCode(iso: "TJ", name: "Tadjikistan", dialCode: "+992"),
    DialCode(iso: "TW", name: "Taïwan", dialCode: "+886"),
    DialCode(iso: "TZ", name: "Tanzanie", dialCode: "+255"),
    DialCode(iso: "TD", name: "Tchad", dialCode: "+235"),
    DialCode(iso: "CZ", name: "Tchéquie", dialCode: "+420"),
    DialCode(iso: "TH", name: "Thaïlande", dialCode: "+66"),
    DialCode(iso: "TL", name: "Timor oriental", dialCode: "+670"),
    DialCode(iso: "TG", name: "Togo", dialCode: "+228"),
    DialCode(iso: "TO", name: "Tonga", dialCode: "+676"),
    DialCode(iso: "TT", name: "Trinité-et-Tobago", dialCode: "+1"),
    DialCode(iso: "TN", name: "Tunisie", dialCode: "+216"),
    DialCode(iso: "TM", name: "Turkménistan", dialCode: "+993"),
    DialCode(iso: "TR", name: "Turquie", dialCode: "+90"),
    DialCode(iso: "TV", name: "Tuvalu", dialCode: "+688"),
    DialCode(iso: "UA", name: "Ukraine", dialCode: "+380"),
    DialCode(iso: "UY", name: "Uruguay", dialCode: "+598"),
    DialCode(iso: "VU", name: "Vanuatu", dialCode: "+678"),
    DialCode(iso: "VA", name: "Vatican", dialCode: "+379"),
    DialCode(iso: "VE", name: "Venezuela", dialCode: "+58"),
    DialCode(iso: "VN", name: "Vietnam", dialCode: "+84"),
    DialCode(iso: "YE", name: "Yémen", dialCode: "+967"),
    DialCode(iso: "ZM", name: "Zambie", dialCode: "+260"),
    DialCode(iso: "ZW", name: "Zimbabwe", dialCode: "+263"),
]

private let DEFAULT_ISO = "MA"

/// ISO 3166-1 alpha-2 -> Unicode regional-indicator flag emoji, e.g. "MA" ->
/// "🇲🇦". Rendered natively via each letter's regional-indicator codepoint.
func flagEmoji(_ iso: String) -> String {
    guard iso.count == 2 else { return "" }
    let base: UInt32 = 0x1F1E6 - UnicodeScalar("A").value
    var result = ""
    for scalar in iso.uppercased().unicodeScalars {
        if let flagScalar = UnicodeScalar(base + scalar.value) {
            result.unicodeScalars.append(flagScalar)
        }
    }
    return result
}

func dialCodeByIso(_ iso: String) -> DialCode {
    DIAL_CODES.first { $0.iso == iso } ?? DIAL_CODES[0]
}

/// Splits a stored phone string into (iso, localNumber) — mirrors
/// dial-codes.ts's parsePhone() / Android's parsePhone(). Matches the longest
/// known dial-code prefix first (so "+21" doesn't shadow Algeria's "+213"),
/// and picks the `primary` entry when several countries share a code.
func parsePhone(_ phone: String?) -> (iso: String, localNumber: String) {
    let trimmed = phone?.trimmingCharacters(in: .whitespaces) ?? ""
    if trimmed.hasPrefix("+") {
        let sortedByLength = DIAL_CODES.sorted { $0.dialCode.count > $1.dialCode.count }
        if let matchedCode = sortedByLength.first(where: { trimmed.hasPrefix($0.dialCode) })?.dialCode {
            let candidates = DIAL_CODES.filter { $0.dialCode == matchedCode }
            let chosen = candidates.first { $0.primary } ?? candidates[0]
            let local = String(trimmed.dropFirst(matchedCode.count)).trimmingCharacters(in: .whitespaces)
            return (chosen.iso, local)
        }
    }
    return (DEFAULT_ISO, trimmed)
}

/// Composes (iso, localNumber) into a single dial-code-prefixed string for
/// storage — strips a leading national trunk "0" and any non-digits.
func composePhone(_ iso: String, _ localNumber: String) -> String {
    var digits = localNumber.filter { $0.isNumber }
    while digits.hasPrefix("0") {
        digits.removeFirst()
    }
    guard !digits.isEmpty else { return "" }
    return "\(dialCodeByIso(iso).dialCode)\(digits)"
}
