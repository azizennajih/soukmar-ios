import Foundation

/// Provider details for the legal pages. They live in the server's environment
/// (never in the app or the repositories) and come from GET /api/legal/operator;
/// the {op_*} tokens in the legal texts are replaced with them.
struct OperatorInfoDto: Decodable {
    let name: String
    let street: String
    let zipCity: String
    let country: String
    let phone: String
    let email: String
    let vatId: String
}

// Plain ObservableObject singleton like I18nRepository/CountryRepository (not @MainActor: SwiftUI views
// hold it in a stored-property initializer); state changes hop to the main actor explicitly.
final class OperatorRepository: ObservableObject {
    static let shared = OperatorRepository()

    @Published private(set) var info: OperatorInfoDto?

    private init() {}

    /// Loads the details once; silently keeps what it has on any failure (offline).
    func load() async {
        guard info == nil else { return }
        do {
            let dto: OperatorInfoDto = try await APIClient.shared.send(path: "legal/operator")
            await MainActor.run { self.info = dto }
        } catch {
            // The tokens stay empty until the next visit.
        }
    }

    /// Replaces the {op_*} tokens of a legal text.
    func fill(_ text: String) -> String {
        guard let info else {
            return text
                .replacingOccurrences(of: "{op_name}", with: "").replacingOccurrences(of: "{op_street}", with: "")
                .replacingOccurrences(of: "{op_zipcity}", with: "").replacingOccurrences(of: "{op_country}", with: "")
                .replacingOccurrences(of: "{op_phone}", with: "").replacingOccurrences(of: "{op_email}", with: "")
                .replacingOccurrences(of: "{op_vat}", with: "")
        }
        return text
            .replacingOccurrences(of: "{op_name}", with: info.name)
            .replacingOccurrences(of: "{op_street}", with: info.street)
            .replacingOccurrences(of: "{op_zipcity}", with: info.zipCity)
            .replacingOccurrences(of: "{op_country}", with: info.country)
            .replacingOccurrences(of: "{op_phone}", with: info.phone)
            .replacingOccurrences(of: "{op_email}", with: info.email)
            .replacingOccurrences(of: "{op_vat}", with: info.vatId)
    }
}
