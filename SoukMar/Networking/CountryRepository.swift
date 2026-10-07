import Foundation

/// Ports the web app's CountryService 1:1 (same as soukmar-android's
/// CountryRepository): the country a visitor is browsing/listing in,
/// persisted independently of language and of the auth session, defaulting
/// to Morocco. On a genuine first launch (nothing saved yet) it best-effort
/// auto-detects the visitor's country via a free IP-geolocation lookup,
/// exactly like the web app's CountryService.detectCountryFromIp() — see
/// soukmar/src/app/services/country.service.ts for the source this mirrors.
///
/// A plain `ObservableObject` singleton, same shape as `I18nRepository`: any
/// SwiftUI view holding `@ObservedObject var countryRepository =
/// CountryRepository.shared` re-renders automatically when `country`
/// changes, since it's `@Published`.
private struct GeoCountryDto: Decodable {
    let country: String?
}

final class CountryRepository: ObservableObject {
    static let shared = CountryRepository()
    static let defaultCountry = "MA"
    private static let userDefaultsKey = "soukmar_country"

    @Published private(set) var country: String

    // Deliberately a bare URLSession, NOT APIClient — APIClient's `request()`
    // auto-attaches our own API Bearer token to every call via a header, which
    // must never be sent to a third-party IP-geolocation service.
    private let session = URLSession(configuration: .ephemeral)

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
        if let saved {
            country = isKnownCountry(saved) ? saved : Self.defaultCountry
        } else {
            country = Self.defaultCountry
            detectCountryFromIp()
        }
    }

    func setCountry(_ code: String) {
        guard code != country else { return }
        country = code
        UserDefaults.standard.set(code, forKey: Self.userDefaultsKey)
    }

    /// Best-effort only: on any failure (no network, unknown country,
    /// malformed response) this silently keeps the default country — a
    /// convenience default is not worth surfacing an error for.
    private func detectCountryFromIp() {
        // Our own backend looks the country up locally from the request IP — no third-party service sees it.
        Task {
            do {
                let geo: GeoCountryDto = try await APIClient.shared.send(path: "geo/country")
                guard let code = geo.country?.uppercased(), isKnownCountry(code) else { return }
                await MainActor.run {
                    self.country = code
                    UserDefaults.standard.set(code, forKey: Self.userDefaultsKey)
                }
            } catch {
                // Network error, timeout, malformed JSON — keep the default.
            }
        }
    }
}
