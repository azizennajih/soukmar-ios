# SoukMar iOS — Claude Working Guide

## Projekt

Native iOS-App (SwiftUI) für SoukMar, spiegelt [[soukmar]] (Angular-Web) und [[soukmar-android]] (Kotlin/Compose) — gleicher Backend-Vertrag (`soukmar-backend`, `http://<host>:3000/api/`), gleiche Feature-Phasen, aber eigenständiges Xcode/Swift-Projekt.

**Pfad:** `C:\AIProjekte\soukmar-ios`
**GitHub:** github.com/azizennajih/soukmar-ios
**Stack:** SwiftUI (iOS 16+), `async`/`await` + `URLSession` (kein Alamofire o.ä. — bewusst schlank gehalten wie Androids reines Retrofit-Setup), Keychain für Session-Persistenz.

---

## Besonderheit dieses Projekts: kein lokaler Mac

Diese gesamte Session läuft auf Windows — **es gibt keinen lokalen Mac und kein Xcode**. Das bedeutet:

1. **Kein `xcodeproj`/`xcworkspace` wird committed.** Stattdessen beschreibt `project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)-Spec) die Projektstruktur als lesbares YAML; `xcodegen generate` erzeugt daraus das eigentliche Xcode-Projekt — sowohl lokal auf einem echten Mac als auch in der CI. Neue Dateien/Targets/Settings **immer in `project.yml` ändern**, nie ein `.xcodeproj` von Hand pflegen (existiert hier gar nicht im Repo).
2. **Verifikation läuft ausschließlich über Codemagic CI** (`codemagic.yaml`), nicht über einen lokalen Build+Simulator-Lauf wie bei Android (dort: Gradle + adb + Emulator, alles lokal möglich). Nach jeder Code-Änderung: committen, pushen, den Codemagic-Build abwarten/prüfen (`gh` oder die Codemagic-Weboberfläche), Fehler beheben, erneut pushen. **Kein Build = keine Verifikation** — Code, der nie durch Codemagic gelaufen ist, gilt als ungetestet.
3. Der Nutzer testet die fertige App auf einem **iPad** — dafür entweder (a) TestFlight (braucht ein bezahltes Apple Developer Program-Konto, aktuell **nicht eingerichtet**) oder (b) einen gemieteten Cloud-Mac mit Fernzugriff. Bis das Apple-Konto steht, validiert der `simulator-build`-Workflow in `codemagic.yaml` nur, dass der Code kompiliert (kein Code-Signing, kein Gerät, keine TestFlight-Auslieferung).

## Codemagic-Setup (einmalig, nur der Nutzer kann das tun)

1. Auf [codemagic.io](https://codemagic.io) mit dem GitHub-Account einloggen (kostenloses Basic-Tier reicht für den Anfang).
2. Repo `azizennajih/soukmar-ios` verbinden — Codemagic erkennt `codemagic.yaml` automatisch.
3. Workflow `simulator-build` manuell starten (oder auf Push automatisch triggern lassen, in den Codemagic-Workflow-Einstellungen konfigurierbar).
4. Ergebnis prüfen: **BUILD SUCCESSFUL** bestätigt, dass der aktuelle Codestand kompiliert — mehr nicht (kein Signing, kein Simulator-Lauf, keine UI-Tests bisher).

Sobald ein Apple Developer Program-Konto existiert: zweiten Workflow (`device-build` o.ä.) mit Code-Signing (App Store Connect API Key in den Codemagic-Umgebungsvariablen hinterlegen) + `publishing.app_store_connect` für TestFlight ergänzen — noch nicht umgesetzt.

---

## Architektur-Konventionen

- **Keine externen Networking-Libraries** — reines `URLSession` + `async/await` (`Networking/APIClient.swift`), mirrort Androids Retrofit-Schicht 1:1 im Vertrag (gleiche Endpunkte, gleiche Fehlerform `{error, unverified?}` → `ApiErrorDto`).
- **MVVM**: `ObservableObject`-ViewModels (`@Published`-Properties) pro Screen, analog zu Androids Hilt-ViewModels — hier ohne DI-Framework, `XRepository.shared`-Singletons genügen für den aktuellen Umfang.
- **Session-Persistenz**: `Persistence/TokenStore.swift`, Keychain für den JWT (sicherer Default als Androids DataStore-Preferences, die dort auch nicht verschlüsselt sind — bewusst besser gemacht, kein Nachteil).
- **Models**: `Codable`-Structs unter `Models/`, Feldnamen exakt wie in `soukmar-backend`/Androids DTOs (z. B. `UserDto`, `LoginRequest`) — bei neuen Endpunkten immer zuerst die Android-DTOs oder die Backend-Route lesen, nicht neu raten.
- **Design-Farben**: `Views/CommonComponents.swift`'s `Color.soukmar*`-Extension — exakt dieselbe Palette wie `soukmar-android/.../theme/Color.kt` und `soukmar/src/styles.scss` (`--primary` = `#D93D4A` etc.). Bei Änderungen alle drei synchron halten.
- **i18n**: noch nicht portiert (kommt in einer späteren iOS-Phase, mirrort Androids Phase-13-Ansatz: Web-JSONs 1:1 als Bundle-Resources übernehmen, keine eigene Übersetzungspflege).

---

## Phasenplan (mirrort soukmar-android, aber eigenständig durchnummeriert)

Reihenfolge und Stand:

1. ✅ **Auth (Login, Register, Passwort vergessen)** — `Views/LoginView.swift`, `RegisterView.swift`, `ForgotPasswordView.swift` + zugehörige ViewModels, echte Push-Navigation zwischen den dreien via `RootView.swift`'s `AuthFlowView` (`NavigationStack` + Enum-Route, mirrort Androids Login/Register/ForgotPassword-Nav-Graph-Einträge). **ResetPassword fehlt noch** (braucht einen per E-Mail zugestellten Deep-Link-Token — Universal Links/Deep-Linking für iOS ist eigene Recherche, noch nicht angegangen). **Codemagic-Build #2 bestätigt grün** (Commit `d2b2cbe`, 1m 11s).
2. ✅ **Home + Anzeigen durchsuchen/suchen** — `Views/HomeView.swift` (Begrüßung, Such-Einstieg, Kategorien-Grid aus `Models/CatalogModels.swift`s `CATEGORIES`, Push-Navigation via eigenem `Route`-Enum wie in `RootView`), `Views/ListingsView.swift` (Kategorie-/Zustand-Chips, Suchleiste, Filter-Sheet mit Preis-Range + dynamischen EAV-Attributen aus `catalog/categories/{category}/full`, paginiertes Grid via `onAppear`-Trigger auf der letzten Karte), `Views/ListingCardView.swift`, `ViewModels/ListingsViewModel.swift` (spiegelt Androids `ListingsViewModel.kt` 1:1: `buildParams()` mit exakt denselben Query-Keys `q`/`category`/`subcategoryId`/`condition`/`minPrice`/`maxPrice`/`attr_<CODE>`/`attr_<CODE>_min`/`_max`), `Models/ListingModels.swift`, `Networking/ListingRepository.swift` + `CatalogRepository.swift`, `APIClient`s neuer Query-Param-`send(path:query:)`-Overload. **Bewusst ausgelassen** (spätere iOS-Phase, Androids Phase-10-Äquivalent): gespeicherte Suchen, Sortierung (`tri`), Karten-Tap navigiert noch nirgends hin (Anzeigendetail ist Phase 3). **Wichtige Vorsichtsmaßnahme ohne lokalen Compiler**: Swifts automatisch generiertes `Decodable` ignoriert Property-Defaults bei fehlendem JSON-Key (anders als Kotlinx auf Android) — `ListingDto`, `ListingsResponseDto`, `AttributeDefinitionDto`, `SubcategoryWithAttributesDto`, `CategoryFullResponse` haben deshalb manuelle `init(from:)` mit `decodeIfPresent(...) ?? default`, gegen das Backend (`soukmar-backend/src/routes/listings.ts`s `sanitizeListing()`) verifiziert, das `region`/`phone`/`whatsapp` je nach Eigentümer/`showPhone` komplett aus der Response entfernt. **Codemagic-Build #3 bestätigt grün** (Commit `eac0b79`) — reiner Kompilier-Check, echtes Durchklicken der Filter/Pagination steht noch aus (kein Simulator-Lauf möglich, siehe oben).
3. ✅ **Anzeigendetail** — `Views/ListingDetailView.swift` (Bilder-Galerie via `TabView(.page)`, Preis mit Ø-Preis-Vergleichsbadge (`priceComparisonPct`, 📉/📈 wie im Web), Kategorie-Badge, Beschreibung, dynamische EAV-Attributliste (`SpecRow`-Äquivalent: BOOLEAN→Oui/Non, NUMBER formatiert, SELECT/TEXT via `humanizeCode()`), Favoriten-Herz + Melden-Flag in der Toolbar (nur eingeloggt), Bewertungsformular (Sterne 1–5 + Kommentar, nur wenn `canReview` vom Backend bestätigt), Melden-Sheet mit 10-Zeichen-Mindestlänge), `ViewModels/ListingDetailViewModel.swift` (spiegelt Androids `ListingDetailViewModel.kt`), neue `Networking/ReviewRepository.swift` + `ReportRepository.swift`, `Models/ReviewModels.swift` + `ReportModels.swift` + `CommonModels.swift`, `ListingRepository` um `getFavoriteIds()`/`addFavorite()`/`removeFavorite()` ergänzt. Navigation: `ListingsView` pusht jetzt per `NavigationLink(value: listing.id)` + `.navigationDestination(for: String.self)`. **Bewusst ausgelassen** (spätere iOS-Phasen): "Contacter le vendeur" (Chat ist Phase 5), Verkäuferprofil-Link (Phase 9). **Wichtiger Navigation-Fix dabei gefunden**: `HomeView`s `NavigationStack` nutzte einen streng typisierten `[Route]`-Pfad — das trägt aber nur *einen* Zieltyp für den ganzen Stack; da `ListingsView` jetzt zusätzlich einen `String` (Listing-ID) pusht, wurde auf `NavigationPath` (type-erased) umgestellt, sonst hätte der Karten-Tap zur Laufzeit vermutlich lautlos nicht navigiert — ohne Simulator nicht zur Laufzeit prüfbar, daher vorsorglich korrekt gemacht statt erst bei echtem Testen zu entdecken — **erster Versuch schlug trotzdem fehl** (Commit `a3fdd2c`): `NavigationPath.append()` ist generisch über `Hashable`, weshalb die Kurzschreibweise `.listings(category: nil)` nicht mehr zu `Route` aufgelöst werden konnte (`type 'Decodable' has no member 'listings'`) — beim alten, streng typisierten `[Route]`-Array ging das noch, weil `Array.append(_:)` nicht generisch über den Elementtyp selbst ist. Gefixt durch explizites `Route.listings(...)` (Commit `bae08a3`). **Codemagic-Build #5 bestätigt grün** (Commit `bae08a3`).
4. ⬜ Anzeige aufgeben
5. ⬜ Chat
6. ⬜ Meine Anzeigen
7. ⬜ Favoriten
8. ⬜ Profil
9. ⬜ Verkäuferprofil
10. ⬜ Gespeicherte Suchen
11. ⬜ Benachrichtigungen (Push via APNs statt FCM — eigene Recherche nötig, nicht 1:1 von Android übertragbar)
12. ⬜ Admin (Meldungen)
13. ⬜ i18n (6 Sprachen, Web-JSONs als Source of Truth wie bei Android)

**Vor jeder neuen Phase**: die passende Web-Implementierung (`soukmar/`) UND die bereits fertige Android-Implementierung (`soukmar-android/`) lesen — Android hat die ganze Recherche- und Edge-Case-Arbeit schon einmal gemacht (Backend-Endpunkte, exakte Feldnamen, Business-Regeln), das erspart erneutes Nachschlagen im Backend-Code.

---

## Wichtige Dateipfade

| Was | Pfad |
|-----|------|
| XcodeGen-Spec | `project.yml` |
| CI-Konfiguration | `codemagic.yaml` |
| App-Einstieg | `SoukMar/SoukMarApp.swift` |
| Root-Navigation (Login/Home-Switch) | `SoukMar/Views/RootView.swift` |
| Networking | `SoukMar/Networking/APIClient.swift` |
| Session-Speicher | `SoukMar/Persistence/TokenStore.swift` |
| Demo-Accounts | `ahmed@soukmar.ma` / `fatima@soukmar.ma` / `youssef@soukmar.ma` (Passwort je `soukmar123`) — `youssef` ist ADMIN |

## Testen

Kein lokaler Emulator/Simulator verfügbar (kein Mac). Ablauf nach jeder Änderung:
1. Lokal nur auf offensichtliche Swift-Syntaxfehler prüfen (kein echter Compiler verfügbar) — vorsichtiger/genauer schreiben als bei Android, wo ein lokaler Gradle-Build sofort Fehler zeigt.
2. Committen + pushen zu `github.com/azizennajih/soukmar-ios`.
3. Codemagic-Build abwarten (Nutzer startet ihn aktuell manuell in der Codemagic-UI, bis Auto-Trigger eingerichtet ist) — Ergebnis vom Nutzer erfragen oder, falls ein Codemagic-API-Token hinterlegt wird, später automatisiert abfragen.
4. Bei Fehlern: Fix, erneut committen/pushen/prüfen — **nicht als "fertig" melden, ohne dass ein Codemagic-Build grün war.**
