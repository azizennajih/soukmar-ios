import SwiftUI

/// Flag+code button opening a menu of all 6 languages — mirrors the web
/// navbar's / Android's LanguageSwitcher (same flags/labels, same 6
/// languages).
struct LanguageSwitcher: View {
    @ObservedObject private var i18n = I18nRepository.shared

    private var current: LanguageOption {
        SUPPORTED_LANGUAGES.first { $0.code == i18n.currentLang } ?? SUPPORTED_LANGUAGES[0]
    }

    var body: some View {
        Menu {
            ForEach(SUPPORTED_LANGUAGES, id: \.code) { option in
                Button {
                    i18n.setLang(option.code)
                } label: {
                    if option.code == i18n.currentLang {
                        Label("\(option.flag) \(option.label)", systemImage: "checkmark")
                    } else {
                        Text("\(option.flag) \(option.label)")
                    }
                }
            }
        } label: {
            Text("\(current.flag) \(current.label)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    LanguageSwitcher()
}
