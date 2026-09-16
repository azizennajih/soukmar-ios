import SwiftUI

/// Country-code (flag + dial code) picker + local-number field that together
/// compose one dial-code-prefixed string (e.g. "+212612345678") for storage
/// in `value` — mirrors soukmar-android's `PhoneInputField`/`PhoneInput`,
/// which itself mirrors the web's `app-phone-input`. Drop-in replacement for
/// a plain phone `TextField`.
struct PhoneInputField: View {
    @Binding var value: String
    @ObservedObject private var i18n = I18nRepository.shared

    @State private var iso: String = "MA"
    @State private var localNumber: String = ""
    @State private var pickerOpen = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                pickerOpen = true
            } label: {
                HStack(spacing: 6) {
                    Text(flagEmoji(iso))
                    Text(dialCodeByIso(iso).dialCode).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)

            TextField("6 00 00 00 00", text: $localNumber)
                .keyboardType(.phonePad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .onChange(of: localNumber) { newValue in
                    value = composePhone(iso, newValue)
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1.5))
        .onAppear { syncFromValue() }
        .onChange(of: value) { newValue in
            guard composePhone(iso, localNumber) != newValue else { return }
            syncFromValue()
        }
        .sheet(isPresented: $pickerOpen) {
            CountryPickerSheet(selectedIso: iso) { picked in
                iso = picked
                value = composePhone(picked, localNumber)
                pickerOpen = false
            }
        }
    }

    private func syncFromValue() {
        let parsed = parsePhone(value)
        iso = parsed.iso
        localNumber = parsed.localNumber
    }
}

private struct CountryPickerSheet: View {
    let selectedIso: String
    let onSelect: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [DialCode] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return DIAL_CODES }
        return DIAL_CODES.filter {
            $0.name.lowercased().contains(q) || $0.dialCode.contains(q) || $0.iso.lowercased() == q
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(i18n.t("common.no_results")).foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { entry in
                        Button {
                            onSelect(entry.iso)
                        } label: {
                            HStack {
                                Text(flagEmoji(entry.iso))
                                Text(entry.name).foregroundStyle(.primary)
                                Spacer()
                                Text(entry.dialCode).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(entry.iso == selectedIso ? Color.soukmarPrimaryLight : Color(.systemBackground))
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
}
