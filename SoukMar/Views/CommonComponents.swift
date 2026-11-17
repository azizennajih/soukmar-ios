import SwiftUI

// Colours, spacing, button and field styles live in DesignSystem.swift.

struct SoukMarLogo: View {
    var markSize: CGFloat = 32
    var fontSize: CGFloat = 20

    var body: some View {
        HStack(spacing: markSize * 0.25) {
            SoukMarMark(size: markSize)
            HStack(spacing: 0) {
                Text("SouqMar").foregroundStyle(Color.soukmarInk)
                Text("24").foregroundStyle(Color.soukmarPrimary)
            }
            .font(.system(size: fontSize, weight: .black))
        }
        // The wordmark is a brand: it always reads "S SouqMar24" left to right, also in RTL languages.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SouqMar24")
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
                        .frame(minHeight: 48)
                }
                .foregroundStyle(isSelected ? Color.soukmarPrimary : Color.soukmarInk)
                .background(isSelected ? Color.soukmarPrimaryLight : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.soukmarPrimary : Color.soukmarBorder, lineWidth: 1.5)
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
            .textFieldStyle(SoukTextFieldStyle())
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
        .foregroundStyle(Color.soukmarSuccess)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.soukmarSuccessLight)
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

/// Follow/unfollow toggle for a seller or buyer profile — mirrors the
/// web's app-follow-button / Android's FollowButton (reused on
/// SellerProfileView and MesAbonnementsView). No confirmation: following
/// isn't destructive, unlike blocking a user in chat.
struct FollowButton: View {
    let following: Bool
    let submitting: Bool
    let onToggle: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        Button(action: onToggle) {
            Label(i18n.t(following ? "seller.unfollow" : "seller.follow"), systemImage: following ? "person.fill.checkmark" : "person.fill.badge.plus")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(following ? Color.soukmarBorder : Color.soukmarPrimary)
        .foregroundStyle(following ? Color.primary : Color.white)
        .disabled(submitting)
    }
}

/// Error message of a form or screen: says what went wrong, with an icon so it is not carried by colour alone.
struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle")
            Text(message)
        }
        .font(.subheadline)
        .foregroundStyle(Color.soukmarErrorDark)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.soukmarErrorLight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

struct SuccessBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle")
            Text(message)
        }
        .font(.subheadline)
        .foregroundStyle(Color.soukmarSuccessDark)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.soukmarSuccessLight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}
