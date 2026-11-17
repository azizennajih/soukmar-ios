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

## Phasenplan / Verlauf

Alle Phasen (1–13) und Tranchen 1–30 sind abgeschlossen. Das ausführliche Protokoll (je Eintrag: Was, Warum, Fallstricke, Testergebnis) steht in `docs/phasen-verlauf.md`. **Nicht komplett lesen**, nur gezielt nach dem passenden Stichwort suchen (Grep) — es ist sehr lang.

Bei einer neuen Tranche: Eintrag **unten an `docs/phasen-verlauf.md` anhängen** (kurz: Datum, Thema, Dateien, Fallstricke, was getestet/nicht getestet ist) — nicht in diese Datei.

---

## Arbeitsweise (Tokens sparen)
- Große Dateien **nie komplett lesen**: die i18n-JSON-Dateien (je >1500 Zeilen), `package-lock.json`, `docs/phasen-verlauf.md`, Build-Logs. Stattdessen Grep nach dem Schlüssel/Stichwort oder `Read` mit `offset`/`limit`.
- Erst gezielt suchen (Grep/Glob), dann nur die betroffene Stelle lesen; nicht ganze Ordner durchlesen.
- Lange Befehlsausgaben filtern (`Select-String`, `| Select-Object -Last 20`), besonders bei Gradle, npm und Tests.
- Pro Aufgabe eine **neue Sitzung** (`/clear`): ein langer Verlauf wird bei jeder Nachricht mitgetragen. Dauerhaftes Wissen gehört in diese Datei oder ins Memory, nicht in den Chatverlauf.

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
