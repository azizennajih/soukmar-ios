import SwiftUI

/// Free-text field with catalog-code suggestions, e.g. the Jobs category's
/// "Beruf" field — mirrors soukmar-android's `TextAutocompleteField`, which
/// itself mirrors the web's `TextAutocompleteComponent`: the typed value
/// itself is what gets stored (never constrained to one of the suggested
/// codes), suggestions are purely a shortcut. Picking a suggestion writes
/// its *translated label* into the field, matching the web's `pick(opt.label)`
/// (so the stored value is whatever label was current in the active language
/// at pick time, not the raw code).
struct TextAutocompleteField: View {
    @Binding var value: String
    let options: [String]
    let labelPrefix: String
    var placeholder: String = ""

    @ObservedObject private var i18n = I18nRepository.shared
    @FocusState private var isFocused: Bool
    @State private var suppressSuggestions = false

    private var filtered: [(code: String, label: String)] {
        let labeled = options.map { ($0, i18n.tCatalog("\(labelPrefix)\($0)", code: $0)) }
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return labeled }
        let q = Self.normalize(value)
        return labeled.filter { Self.normalize($0.1).contains(q) }
    }

    private var showMenu: Bool { isFocused && !suppressSuggestions && !filtered.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: value) { _ in suppressSuggestions = false }

            if showMenu {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered.prefix(60), id: \.code) { item in
                            Button {
                                value = item.label
                                suppressSuggestions = true
                                isFocused = false
                            } label: {
                                Text(item.label)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// Diacritic-insensitive, case-insensitive normalization — mirrors
    /// Android's `Normalizer.normalize(NFD) + strip combining marks`.
    private static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
