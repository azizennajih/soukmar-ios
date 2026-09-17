import SwiftUI

/// Generic content view for all four legal pages (mentions légales, politique
/// de confidentialité, conditions d'utilisation, droit de rétractation) —
/// mirrors soukmar-android's `LegalPageScreen`, which itself mirrors the
/// web's shared `legal-page.component`. Content lives entirely in the shared
/// i18n JSON assets, no backend involved.
struct LegalPageView: View {
    let titleKey: String
    let namespace: String
    let sectionCount: Int
    /// Only the "mentions légales" page passes this — links to the other
    /// three legal pages, mirroring Android's `extraLinks` hub pattern.
    var extraLinks: (() -> AnyView)? = nil

    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t("legal.last_updated")).font(.caption).foregroundStyle(.secondary)
                Spacer().frame(height: 12)
                ForEach(1...sectionCount, id: \.self) { n in
                    Text(i18n.t("\(namespace).s\(n)_title")).font(.headline)
                    Spacer().frame(height: 4)
                    Text(i18n.t("\(namespace).s\(n)_body")).font(.subheadline)
                    Spacer().frame(height: 16)
                }
                if let extraLinks {
                    extraLinks()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(i18n.t(titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalLinkRow: View {
    let label: String
    let destination: LegalRoute

    var body: some View {
        NavigationLink(value: destination) {
            HStack {
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        Divider()
    }
}

/// Hashable wrapper for the three legal pages a "mentions légales" hub links
/// to — mirrors the pattern already used for `ConversationRoute`/`SellerRoute`
/// (a second meaning sharing the same navigationDestination(for:) stack needs
/// its own type, not a bare String/enum case reused ambiguously).
struct LegalRoute: Hashable {
    let namespace: String
    let titleKey: String
    let sectionCount: Int

    static let privacy = LegalRoute(namespace: "legal.privacy", titleKey: "legal.privacy_title", sectionCount: 11)
    static let terms = LegalRoute(namespace: "legal.terms", titleKey: "legal.terms_title", sectionCount: 14)
    static let withdrawal = LegalRoute(namespace: "legal.withdrawal", titleKey: "legal.withdrawal_title", sectionCount: 6)
}

struct LegalNoticeView: View {
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        LegalPageView(titleKey: "legal.notice_title", namespace: "legal.notice", sectionCount: 6) {
            AnyView(
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 8)
                    Text(i18n.t("parametres.legal")).font(.headline)
                    LegalLinkRow(label: i18n.t("legal.privacy_title"), destination: .privacy)
                    LegalLinkRow(label: i18n.t("legal.terms_title"), destination: .terms)
                    LegalLinkRow(label: i18n.t("legal.withdrawal_title"), destination: .withdrawal)
                }
            )
        }
        .navigationDestination(for: LegalRoute.self) { route in
            LegalPageView(titleKey: route.titleKey, namespace: route.namespace, sectionCount: route.sectionCount)
        }
    }
}
