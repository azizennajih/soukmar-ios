import SwiftUI

/// Same palette as soukmar-android's ui/theme/Color.kt and the web's
/// styles.scss CSS variables — keep these three in sync.
extension Color {
    static let soukmarPrimary = Color(red: 0xD9 / 255, green: 0x3D / 255, blue: 0x4A / 255)
    static let soukmarPrimaryLight = Color(red: 0xFE / 255, green: 0xF1 / 255, blue: 0xF2 / 255)
    static let soukmarGold = Color(red: 0xC9 / 255, green: 0x94 / 255, blue: 0x1A / 255)
    static let soukmarGoldLight = Color(red: 0xFE / 255, green: 0xF6 / 255, blue: 0xE4 / 255)
    static let soukmarTextMuted = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
}

struct SoukMarLogo: View {
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.soukmarPrimary)
                .frame(width: 36, height: 36)
                .overlay(Text("S").font(.headline.bold()).foregroundStyle(.white))
            HStack(spacing: 0) {
                Text("SouqMar").fontWeight(.black)
                Text("24").fontWeight(.black).foregroundStyle(Color.soukmarPrimary)
            }
            .font(.title3)
        }
    }
}

/// Mirrors soukmar-android's AccountTypeSelector composable — two side-by-side
/// toggle buttons for the PRIVATE/BUSINESS choice required at registration
/// (and, in a later phase, editable from the profile).
struct AccountTypeSelector: View {
    @Binding var selected: String
    let options: [(value: String, label: String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                let isSelected = selected == option.value
                Button {
                    selected = option.value
                } label: {
                    Text(option.label)
                        .fontWeight(isSelected ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .foregroundStyle(isSelected ? Color.soukmarPrimary : .primary)
                .background(isSelected ? Color.soukmarPrimaryLight : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.soukmarPrimary : Color(.systemGray4), lineWidth: 1.5)
                )
            }
        }
    }
}

/// Secure field with a show/hide eye toggle that auto-hides again after 8s —
/// mirrors soukmar-android's `AppTextField(isPassword = true)`, which itself
/// mirrors the web's password-input component. Drop-in replacement for a
/// plain `SecureField`.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.trailing, 30)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 10)
        }
        .onChange(of: isVisible) { newValue in
            hideTask?.cancel()
            guard newValue else { return }
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if !Task.isCancelled { isVisible = false }
            }
        }
    }
}

/// Trust-signal badge mirroring the web's `app-verified-badge` (and
/// soukmar-android's `VerifiedBadge`): renders nothing if neither flag is
/// set, so an unverified account just shows no badge rather than a warning.
struct VerifiedBadge: View {
    let emailVerified: Bool
    let phoneVerified: Bool
    var idVerified: Bool = false
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        if emailVerified || phoneVerified || idVerified {
            HStack(spacing: 4) {
                if emailVerified { pill(i18n.t("seller.email_verified_short")) }
                if phoneVerified { pill(i18n.t("seller.phone_verified_short")) }
                if idVerified { pill(i18n.t("seller.id_verified_short")) }
            }
        }
    }

    private func pill(_ label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
            Text(label).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Small icon+label row for a seller's account type (Privat/Gewerblich) —
/// mirrors the web's business/private icon+text pairing and Android's
/// `AccountTypeLabel`. Renders nothing for a nil/unknown type.
struct AccountTypeLabel: View {
    let accountType: String?
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        if let accountType {
            let isBusiness = accountType == "BUSINESS"
            HStack(spacing: 4) {
                Image(systemName: isBusiness ? "building.2" : "person")
                    .font(.system(size: 11))
                Text(i18n.t(isBusiness ? "auth.account_type_business" : "auth.account_type_private"))
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SuccessBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
        }
        .font(.subheadline)
        .foregroundStyle(.green)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
