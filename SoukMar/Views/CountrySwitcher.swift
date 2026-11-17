import SwiftUI

/// Flag+code button opening a searchable, continent-grouped country picker —
/// mirrors soukmar-android's `CountrySwitcher` (same ~193 countries, same
/// Morocco-first/continent grouping, same search-to-filter behavior), which
/// itself mirrors the web navbar's country switcher. Placed next to
/// `LanguageSwitcher` wherever the web navbar would show both. Flag is a
/// plain computed emoji (reuses `flagEmoji()` from DialCodes.swift) — iOS has
/// no equivalent of web's Windows-Chrome flag-rendering bug that forced
/// bundled SVG icons there.
///
/// `country`/`onSelect` default to nil, which falls back to the shared
/// `CountryRepository` (the app-wide default used on Home/Login) via the
/// `@ObservedObject` below, so the default call site stays fully reactive to
/// changes made elsewhere. Pass them explicitly (as ListingsView's
/// FiltersSheet does, with `viewModel.country`/`viewModel.selectCountry`) to
/// drive a screen-local ViewModel's own country state instead — mirrors
/// Android's `CountrySwitcher(country, onSelect)` signature.
struct CountrySwitcher: View {
    var country: String?
    var onSelect: ((String) -> Void)?
    @ObservedObject private var countryRepository = CountryRepository.shared
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var pickerOpen = false

    private var effectiveCountry: String { country ?? countryRepository.country }

    private func select(_ code: String) {
        if let onSelect { onSelect(code) } else { countryRepository.setCountry(code) }
    }

    var body: some View {
        Button {
            pickerOpen = true
        } label: {
            // Flag + raw ISO code (not the full display name) to stay as
            // compact as LanguageSwitcher's "🇫🇷 FR" — the toolbar has no room
            // for e.g. "🇵🇬 Papouasie-Nouvelle-Guinée"; the full name only
            // appears once the picker sheet itself is open.
            Text("\(flagEmoji(effectiveCountry)) \(effectiveCountry)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .sheet(isPresented: $pickerOpen) {
            CountryPickerSheet(selected: effectiveCountry) { picked in
                select(picked)
                pickerOpen = false
            }
        }
    }
}

private func displayName(_ code: String, locale: Locale) -> String {
    locale.localizedString(forRegionCode: code) ?? code
}

private struct CountryPickerSheet: View {
    let selected: String
    let onSelect: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var uiLocale: Locale { localeForLang(i18n.currentLang) }

    private var filteredFlat: [CountryInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return COUNTRIES.filter { displayName($0.code, locale: uiLocale).lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ForEach(COUNTRY_REGIONS, id: \.region) { group in
                        if !group.codes.isEmpty {
                            Section(i18n.t(regionLabelKey(group.region))) {
                                ForEach(group.codes, id: \.self) { code in
                                    countryRow(code)
                                }
                            }
                        }
                    }
                } else if filteredFlat.isEmpty {
                    Text(i18n.t("common.no_results")).foregroundStyle(.secondary)
                } else {
                    ForEach(filteredFlat, id: \.code) { info in
                        countryRow(info.code)
                    }
                }
            }
            .searchable(text: $query, prompt: i18n.t("common.search"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(i18n.t("common.close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func countryRow(_ code: String) -> some View {
        Button {
            onSelect(code)
        } label: {
            HStack {
                Text(flagEmoji(code))
                Text(displayName(code, locale: uiLocale)).foregroundStyle(.primary)
            }
        }
        .listRowBackground(code == selected ? Color.soukmarPrimaryLight : Color(.systemBackground))
    }
}
