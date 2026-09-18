import SwiftUI

/// Consolidates entry points that used to be scattered across HomeView's
/// overflow menu (profile, legal, logout) plus the delete-account flow,
/// mirroring the web's `/parametres` hub and Android's `SettingsScreen` —
/// minus the Premium/Aide rows, out of scope here (marketing/payment
/// content, not app parity).
struct SettingsView: View {
    let onOpenProfil: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenLegal: () -> Void
    let onOpenDeleteAccount: () -> Void
    let onLoggedOut: () -> Void

    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(i18n.t("nav.settings")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    LanguageSwitcher()
                }
                .padding(.bottom, 4)

                SettingsRow(icon: "person", title: i18n.t("parametres.profile_account"), subtitle: i18n.t("parametres.profile_account_sub"), action: onOpenProfil)
                SettingsRow(icon: "bell", title: i18n.t("parametres.notifications"), subtitle: i18n.t("parametres.notifications_sub"), action: onOpenNotifications)
                SettingsRow(icon: "doc.text", title: i18n.t("parametres.legal"), subtitle: i18n.t("parametres.legal_sub"), action: onOpenLegal)

                Spacer(minLength: 10)
                SettingsRow(icon: "trash", title: i18n.t("parametres.delete_account"), subtitle: i18n.t("parametres.delete_account_sub"), action: onOpenDeleteAccount, danger: true)

                Spacer(minLength: 10)
                Button {
                    AuthRepository.shared.logout()
                    ChatSocketManager.shared.disconnect()
                    onLoggedOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(i18n.t("nav.logout"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("parametres.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var danger: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill((danger ? Color.red : Color.soukmarPrimary).opacity(0.1))
                    Image(systemName: icon)
                        .foregroundStyle(danger ? Color.red : Color.soukmarPrimary)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(danger ? Color.red : .primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
