import SwiftUI

// Souqmar24 design system (redesign 2026-11). Brand identity: red for the important actions (never as a large fill),
// white as the ground, yellow as a deliberate accent for offers and hints.
// Keep in sync with soukmar-android (ui/theme/Color.kt, Dimens.kt) and the web's styles.scss.

extension Color {
    // Red: primary actions, active states, the logo.
    static let soukmarPrimary = Color(red: 0xD9 / 255, green: 0x3D / 255, blue: 0x4A / 255)
    static let soukmarPrimaryDark = Color(red: 0xB8 / 255, green: 0x31 / 255, blue: 0x3C / 255)
    static let soukmarPrimaryLight = Color(red: 0xFE / 255, green: 0xF1 / 255, blue: 0xF2 / 255)

    // Yellow: accent for offers, boosts, premium and hints. soukmarAccent is the fill (always with dark text on it),
    // soukmarGold the readable text/icon tone on a light ground, soukmarGoldLight the tinted ground.
    static let soukmarAccent = Color(red: 0xFF / 255, green: 0xC5 / 255, blue: 0x33 / 255)
    static let soukmarGold = Color(red: 0x8F / 255, green: 0x5F / 255, blue: 0x00 / 255)
    static let soukmarGoldLight = Color(red: 0xFF / 255, green: 0xF6 / 255, blue: 0xDB / 255)

    // Neutrals (fixed light values: the app has one, light appearance).
    static let soukmarInk = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
    static let soukmarTextMuted = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
    static let soukmarTextSubtle = Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255)
    static let soukmarBorder = Color(red: 0xE7 / 255, green: 0xE8 / 255, blue: 0xEC / 255)
    static let soukmarSurfaceMuted = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)

    // Feedback.
    static let soukmarError = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let soukmarErrorLight = Color(red: 0xFE / 255, green: 0xE2 / 255, blue: 0xE2 / 255)
    static let soukmarErrorDark = Color(red: 0xB9 / 255, green: 0x1C / 255, blue: 0x1C / 255)
    static let soukmarSuccess = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
    static let soukmarSuccessLight = Color(red: 0xDC / 255, green: 0xFC / 255, blue: 0xE7 / 255)
    static let soukmarSuccessDark = Color(red: 0x15 / 255, green: 0x80 / 255, blue: 0x3D / 255)
}

/// Spacing scale (4-pt grid). Screen edge padding is `lg`.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii: badges 8, fields 12, cards and sheets 16; buttons, chips and the search are fully round.
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

/// Height of the main buttons and input fields.
let soukControlHeight: CGFloat = 52

// MARK: - Buttons

/// The one primary action of a screen: red, full width, 52 pt.
struct SoukPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: soukControlHeight)
            .padding(.horizontal, Spacing.lg)
            .background(isEnabled ? (configuration.isPressed ? Color.soukmarPrimaryDark : Color.soukmarPrimary) : Color.soukmarTextSubtle)
            .clipShape(Capsule())
    }
}

/// Secondary action next to or below a primary one: white with a border, dark text.
struct SoukSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.soukmarInk : Color.soukmarTextSubtle)
            .frame(maxWidth: .infinity)
            .frame(minHeight: soukControlHeight)
            .padding(.horizontal, Spacing.lg)
            .background(configuration.isPressed ? Color.soukmarSurfaceMuted : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.soukmarBorder, lineWidth: 1))
    }
}

/// Yellow action for offers and boosts (dark text for contrast).
struct SoukAccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.soukmarInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: soukControlHeight)
            .padding(.horizontal, Spacing.lg)
            .background(Color.soukmarAccent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5))
            .clipShape(Capsule())
    }
}

// MARK: - Text fields

/// The text field of every form: 52 pt high, 12-pt corners, hairline border on white.
struct SoukTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: soukControlHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.soukmarBorder, lineWidth: 1))
    }
}

// MARK: - Surfaces

extension View {
    /// The standard card surface: white, 16-pt corners, hairline border, no shadow.
    func soukCard() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.soukmarBorder, lineWidth: 1))
    }
}

// MARK: - Brand mark

/// The brand mark: red rounded tile with the white S (same artwork as the launch screen, Assets: LaunchLogo).
struct SoukMarMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image("LaunchLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Shared building blocks

/// The search entry of the home screen: one large pill, the whole surface is the touch target; photo search on the trailing side.
struct SearchPill: View {
    let placeholder: String
    let cameraLabel: String
    var onTap: () -> Void
    var onCamera: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.soukmarInk)
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(Color.soukmarTextMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, Spacing.lg)
                .frame(maxWidth: .infinity)
                .frame(height: soukControlHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onCamera) {
                Image(systemName: "camera")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.soukmarInk)
                    .frame(width: 48, height: soukControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cameraLabel)
        }
        .background(Color.soukmarSurfaceMuted)
        .clipShape(Capsule())
    }
}

/// Section title with an optional "see all" action on the trailing side.
struct SectionHeader: View {
    let title: String
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.soukmarInk)
            Spacer(minLength: Spacing.sm)
            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.soukmarPrimary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 44)
    }
}

/// Empty or error state of a list: calm icon in a tinted circle, one sentence, at most one action.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.soukmarTextMuted)
                .frame(width: 72, height: 72)
                .background(Color.soukmarSurfaceMuted)
                .clipShape(Circle())
                .padding(.bottom, Spacing.sm)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.soukmarInk)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.soukmarTextMuted)
                    .multilineTextAlignment(.center)
            }
            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .buttonStyle(SoukPrimaryButtonStyle())
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Small label on images and in lists. The yellow accent is reserved for offers, boosts and premium.
struct SoukBadge: View {
    let text: String
    var systemImage: String? = nil
    var background: Color = Color.soukmarSurfaceMuted
    var foreground: Color = Color.soukmarInk

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(.system(size: 11, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

/// One row of a menu list (account, settings): icon, title, chevron (mirrored in RTL by the system image).
struct MenuRow: View {
    let systemImage: String
    let title: String
    var tint: Color = Color.soukmarInk
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(title)
                    .font(.body)
                    .foregroundStyle(tint)
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.soukmarTextSubtle)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Hint in the accent yellow (tips, offers, things to know); not for errors.
struct HintBanner: View {
    let message: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage { Image(systemName: systemImage) }
            Text(message)
        }
        .font(.subheadline)
        .foregroundStyle(Color.soukmarGold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.soukmarGoldLight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

/// The ids of the user's favourites, shared by every listing card so the heart shows the same state on all screens.
/// Pure UI state on top of the existing favourites endpoints, no new backend contract.
@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var ids: Set<String> = []

    func refresh() {
        Task { ids = await ListingRepository.shared.getFavoriteIds() }
    }

    /// Called by screens that changed a favourite through their own view model (detail, favourites list).
    func set(_ id: String, favorite: Bool) {
        if favorite { ids.insert(id) } else { ids.remove(id) }
    }

    func clear() {
        ids = []
    }

    /// Optimistic toggle; reverted when the backend call fails.
    func toggle(_ id: String) {
        let wasFavorite = ids.contains(id)
        set(id, favorite: !wasFavorite)
        Task {
            let ok = wasFavorite ? await ListingRepository.shared.removeFavorite(id: id) : await ListingRepository.shared.addFavorite(id: id)
            if !ok { set(id, favorite: wasFavorite) }
        }
    }
}
