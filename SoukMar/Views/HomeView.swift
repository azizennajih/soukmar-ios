import SwiftUI

/// The four tabs of the bottom bar; "post a listing" in the middle is an action, not a tab.
enum MainTab: Hashable {
    case home, categories, messages, account
}

/// The signed-in shell of the app: one navigation stack whose root shows the selected tab (home, categories, messages,
/// my account) above the bottom bar. Every other screen is pushed on top and covers the bar, as on Android.
struct HomeView: View {
    @State private var user: UserDto? = TokenStore.shared.cachedUser
    @ObservedObject private var i18n = I18nRepository.shared
    var onLoggedOut: () -> Void

    private enum Route: Hashable {
        case listings(category: String?, savedSearchId: String?, editSearchId: String?)
        case listingForm(editId: String?, category: String? = nil)
        case chatList
        case myListings
        case favorites
        case profile
        case savedSearches
        case mesAbonnements
        case notifications
        case admin
        case legalNotice
        case deleteAccount
        case settings
        case myData
        case imageSearch
    }
    // NavigationPath (type-erased), not a plain [Route] array: ListingsView
    // pushes a String (listing id) further down this same stack for
    // ListingDetailView, and a homogeneous typed array can only carry one
    // destination type for the whole stack.
    @State private var path = NavigationPath()
    @State private var tab: MainTab = .home
    @State private var unreadCount = 0
    /// Live listing count per category in the current country (empty until loaded).
    @State private var categoryCounts: [String: Int] = [:]
    /// Advertising banner shown once on the home screen (first INLINE banner of the country).
    @State private var inlineBanners: [SponsorBannerDto] = []
    /// Newest listings of the country (the home feed) and the paid-visibility ones among them.
    @State private var recentListings: [ListingDto] = []
    @State private var featuredListings: [ListingDto] = []
    @State private var feedLoading = true
    @ObservedObject private var countryRepository = CountryRepository.shared

    private let feedColumns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.md, alignment: .top)]

    private func openListings(category: String? = nil) {
        path.append(Route.listings(category: category, savedSearchId: nil, editSearchId: nil))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch tab {
                case .home:
                    homeFeed
                case .categories:
                    CategoriesView(counts: categoryCounts) { category in openListings(category: category) }
                case .messages:
                    ChatListView()
                case .account:
                    AccountView(
                        user: user,
                        onOpenProfil: { path.append(Route.profile) },
                        onOpenMyListings: { path.append(Route.myListings) },
                        onOpenFavorites: { path.append(Route.favorites) },
                        onOpenSavedSearches: { path.append(Route.savedSearches) },
                        onOpenFollows: { path.append(Route.mesAbonnements) },
                        onOpenNotifications: { path.append(Route.notifications) },
                        onOpenSettings: { path.append(Route.settings) },
                        onOpenAdmin: { path.append(Route.admin) }
                    )
                }
            }
            .background(Color.white)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainTabBar(selected: $tab) { path.append(Route.listingForm(editId: nil)) }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .listings(let category, let savedSearchId, let editSearchId):
                    ListingsView(
                        initialCategory: category,
                        savedSearchId: savedSearchId,
                        editSearchId: editSearchId,
                        onPostListing: { selectedCategory in path.append(Route.listingForm(editId: nil, category: selectedCategory)) }
                    )
                case .listingForm(let editId, let presetCategory):
                    DeposerAnnonceView(editId: editId, presetCategory: presetCategory) { newListingId in
                        path.removeLast()
                        path.append(newListingId)
                    }
                case .chatList:
                    ChatListView()
                case .myListings:
                    MesAnnoncesView(
                        onOpenListing: { id in path.append(id) },
                        onEditListing: { id in path.append(Route.listingForm(editId: id)) },
                        onNewListing: { path.append(Route.listingForm(editId: nil)) },
                        onBoostListing: { id in path.append(BoostRoute(listingId: id)) }
                    )
                case .favorites:
                    FavorisView(
                        onOpenListing: { id in path.append(id) },
                        onBrowse: { path.append(Route.listings(category: nil, savedSearchId: nil, editSearchId: nil)) }
                    )
                case .profile:
                    ProfilView()
                case .savedSearches:
                    SavedSearchesView(
                        onOpenSearch: { savedSearchId in
                            path.append(Route.listings(category: nil, savedSearchId: savedSearchId, editSearchId: nil))
                        },
                        onEditSearch: { editSearchId in
                            path.append(Route.listings(category: nil, savedSearchId: nil, editSearchId: editSearchId))
                        }
                    )
                case .mesAbonnements:
                    MesAbonnementsView(
                        onOpenSeller: { sellerId in path.append(SellerRoute(sellerId: sellerId)) },
                        onBrowse: { path.append(Route.listings(category: nil, savedSearchId: nil, editSearchId: nil)) }
                    )
                case .notifications:
                    NotificationsView(
                        onOpenChat: { conversationId in path.append(ConversationRoute(conversationId: conversationId)) },
                        onOpenListing: { id in path.append(id) },
                        onOpenProfil: { path.append(Route.profile) }
                    )
                case .admin:
                    AdminView(onOpenListing: { id in path.append(id) })
                case .legalNotice:
                    LegalNoticeView()
                case .deleteAccount:
                    DeleteAccountView(onLoggedOut: onLoggedOut)
                case .settings:
                    SettingsView(
                        onOpenProfil: { path.append(Route.profile) },
                        onOpenNotifications: { path.append(Route.notifications) },
                        onOpenLegal: { path.append(Route.legalNotice) },
                        onOpenMyData: { path.append(Route.myData) },
                        onOpenDeleteAccount: { path.append(Route.deleteAccount) },
                        onLoggedOut: onLoggedOut
                    )
                case .myData:
                    MesDonneesView()
                case .imageSearch:
                    ImageSearchView(onOpenListing: { id in path.append(id) })
                }
            }
            // Both registered here, not on a leaf screen, so they apply
            // regardless of which route pushed the value — e.g.
            // DeposerAnnonceView's onPublished pushes a listing id directly
            // without ListingsView ever being part of the active stack, and
            // ListingDetailView's "Contacter le vendeur" pushes a
            // ConversationRoute without ChatListView being part of it either.
            // navigationDestination(for:) only takes effect while the view
            // that declared it is present in the stack.
            .navigationDestination(for: String.self) { listingId in
                ListingDetailView(
                    listingId: listingId,
                    onOpenConversation: { conversationId in
                        path.append(ConversationRoute(conversationId: conversationId))
                    },
                    onOpenSeller: { sellerId in
                        path.append(SellerRoute(sellerId: sellerId))
                    }
                )
            }
            .navigationDestination(for: ConversationRoute.self) { route in
                ChatView(conversationId: route.conversationId)
            }
            .navigationDestination(for: SellerRoute.self) { route in
                SellerProfileView(sellerId: route.sellerId) { listingId in
                    path.append(listingId)
                }
            }
            .navigationDestination(for: BoostRoute.self) { route in
                BoostListingView(listingId: route.listingId)
            }
            // Reloads whenever the country changes.
            .task(id: countryRepository.country) {
                do {
                    let counts: [String: Int] = try await APIClient.shared.send(path: "stats/categories", query: ["country": countryRepository.country])
                    categoryCounts = counts
                } catch {
                    categoryCounts = [:]
                }
            }
            .task(id: countryRepository.country) {
                inlineBanners = await SponsorRepository.shared.inlineBanners(country: countryRepository.country)
            }
            .task(id: countryRepository.country) {
                await loadFeed()
            }
            .task {
                FavoritesStore.shared.refresh()
                if let refreshed = await AuthRepository.shared.me() {
                    user = refreshed
                }
            }
            // Mirrors the web navbar's 30-second unread-count poll — the
            // backend has no live-update mechanism for the badge. Runs for
            // as long as HomeView (the app's root screen) stays mounted.
            .task {
                while !Task.isCancelled {
                    unreadCount = await NotificationRepository.shared.getUnreadCount()
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                }
            }
        }
    }

    // MARK: - Home tab

    private var homeFeed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SearchPill(
                    placeholder: i18n.t("nav.search_placeholder"),
                    cameraLabel: i18n.t("nav.search_by_image"),
                    onTap: { openListings() },
                    onCamera: { path.append(Route.imageSearch) }
                )
                .padding(.horizontal, Spacing.lg)

                // Categories at a glance: one horizontal row, the full list is the second tab.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SectionHeader(title: i18n.t("nav.categories"), actionLabel: i18n.t("home.see_all")) { tab = .categories }
                        .padding(.horizontal, Spacing.lg)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            ForEach(CATEGORIES) { cat in
                                Button {
                                    openListings(category: cat.value)
                                } label: {
                                    CategoryChip(category: cat)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                }

                if let banner = inlineBanners.first {
                    SponsorBannerView(banner: banner).padding(.horizontal, Spacing.lg)
                }

                if !featuredListings.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.sm) {
                            Circle().fill(Color.soukmarAccent).frame(width: 8, height: 8)
                            SectionHeader(title: i18n.t("home.featured"))
                        }
                        listingGrid(featuredListings)
                    }
                    .padding(.horizontal, Spacing.lg)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SectionHeader(title: i18n.t("home.recent"), actionLabel: i18n.t("home.see_all")) { openListings() }
                    if feedLoading && recentListings.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.xl)
                    }
                    listingGrid(recentListings)
                }
                .padding(.horizontal, Spacing.lg)

                // The country lives at the very bottom (like the web footer), not in the toolbar.
                CountrySwitcher()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SoukMarLogo(markSize: 28, fontSize: 19)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    path.append(Route.favorites)
                } label: {
                    Image(systemName: "heart")
                }
                .accessibilityLabel(i18n.t("nav.my_favorites"))
                Button {
                    path.append(Route.notifications)
                } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if unreadCount > 0 {
                                Text("\(min(unreadCount, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .padding(3)
                                    .background(Color.soukmarPrimary)
                                    .clipShape(Circle())
                                    .offset(x: 9, y: -9)
                            }
                        }
                }
                .accessibilityLabel(i18n.t("nav.notifications"))
            }
        }
        .tint(Color.soukmarInk)
    }

    private func listingGrid(_ listings: [ListingDto]) -> some View {
        LazyVGrid(columns: feedColumns, spacing: Spacing.md) {
            ForEach(listings) { listing in
                Button {
                    path.append(listing.id)
                } label: {
                    ListingCardView(listing: listing)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadFeed() async {
        feedLoading = true
        switch await ListingRepository.shared.getListings(params: ["limit": "20", "country": countryRepository.country]) {
        case .success(let response):
            let all = response.listings
            let featured = Array(all.filter { $0.isFeatured || isBoostActive($0.boostGlobalUntil) || isBoostActive($0.boostTopUntil) }.prefix(8))
            let featuredIds = Set(featured.map { $0.id })
            featuredListings = featured
            recentListings = all.filter { !featuredIds.contains($0.id) }
        case .failure:
            featuredListings = []
            recentListings = []
        }
        feedLoading = false
    }
}

/// Round icon with the category name below; 76 pt wide, so the whole chip is a comfortable touch target.
struct CategoryChip: View {
    let category: CategoryConfig
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(category.bg)
                .frame(width: 60, height: 60)
                .overlay(CategoryIcon(category: category.value, tint: category.fg).frame(width: 28, height: 28))
            Text(i18n.tCatalog("cats.\(category.value)", code: category.value))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.soukmarInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 76)
        .contentShape(Rectangle())
    }
}

/// Bottom bar of the main screens: home, categories, post a listing (the red round button in the middle, the most visible
/// element), messages, my account. Same icon size and label style everywhere; outline icon when idle, filled and red when
/// selected. Sits above the home indicator (safe area) on every device.
struct MainTabBar: View {
    @Binding var selected: MainTab
    var onPost: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.soukmarBorder).frame(height: 1)
            HStack(alignment: .center, spacing: 0) {
                tabItem(.home, icon: "house", label: i18n.t("nav.home"))
                tabItem(.categories, icon: "square.grid.2x2", label: i18n.t("nav.categories"))
                Button(action: onPost) {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 40, height: 40)
                            .background(Color.soukmarPrimary)
                            .clipShape(Circle())
                        Text(i18n.t("nav.post_btn"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.soukmarInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i18n.t("nav.post_full"))
                tabItem(.messages, icon: "bubble.left", label: i18n.t("nav.messages"))
                tabItem(.account, icon: "person", label: i18n.t("nav.account"))
            }
            .padding(.top, 2)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }

    private func tabItem(_ tab: MainTab, icon: String, label: String) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.soukmarPrimary : Color.soukmarTextMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// All categories in the four groups of the web home page, one tidy list: icon, name, number of listings.
struct CategoriesView: View {
    let counts: [String: Int]
    var onOpenCategory: (String) -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(CATEGORY_GROUPS, id: \.key) { group in
                    Text(i18n.t("home.cat_group_\(group.key)"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.soukmarTextMuted)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.xs)
                    ForEach(group.categories) { cat in
                        Button {
                            onOpenCategory(cat.value)
                        } label: {
                            HStack(spacing: Spacing.lg) {
                                Circle()
                                    .fill(cat.bg)
                                    .frame(width: 44, height: 44)
                                    .overlay(CategoryIcon(category: cat.value, tint: cat.fg).frame(width: 24, height: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i18n.tCatalog("cats.\(cat.value)", code: cat.value))
                                        .font(.body)
                                        .foregroundStyle(Color.soukmarInk)
                                    if let count = counts[cat.value], count > 0 {
                                        Text(count == 1 ? i18n.t("home.category_count_one") : i18n.t("home.category_count", ["count": String(count)]))
                                            .font(.caption)
                                            .foregroundStyle(Color.soukmarTextMuted)
                                    }
                                }
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: "chevron.forward")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.soukmarTextSubtle)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 64)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .navigationTitle(i18n.t("nav.categories"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "My account" tab: who is signed in, then everything that used to hide in the overflow menu and the toolbar, as one clear list.
struct AccountView: View {
    let user: UserDto?
    var onOpenProfil: () -> Void
    var onOpenMyListings: () -> Void
    var onOpenFavorites: () -> Void
    var onOpenSavedSearches: () -> Void
    var onOpenFollows: () -> Void
    var onOpenNotifications: () -> Void
    var onOpenSettings: () -> Void
    var onOpenAdmin: () -> Void
    @ObservedObject private var i18n = I18nRepository.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let user {
                    Button(action: onOpenProfil) {
                        HStack(spacing: Spacing.lg) {
                            avatar(user)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color.soukmarInk)
                                    .lineLimit(1)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(Color.soukmarTextMuted)
                                    .lineLimit(1)
                                VerifiedBadge(emailVerified: user.emailVerified, phoneVerified: user.phoneVerified, idVerified: user.idVerified)
                            }
                            Spacer(minLength: Spacing.sm)
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.soukmarTextSubtle)
                        }
                        .padding(Spacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .soukCard()
                }

                VStack(spacing: 0) {
                    MenuRow(systemImage: "list.bullet.rectangle", title: i18n.t("nav.my_listings"), action: onOpenMyListings)
                    divider
                    MenuRow(systemImage: "heart", title: i18n.t("nav.my_favorites"), action: onOpenFavorites)
                    divider
                    MenuRow(systemImage: "bookmark", title: i18n.t("nav.saved_searches"), action: onOpenSavedSearches)
                    divider
                    MenuRow(systemImage: "person.2", title: i18n.t("nav.my_follows"), action: onOpenFollows)
                    divider
                    MenuRow(systemImage: "bell", title: i18n.t("nav.notifications"), action: onOpenNotifications)
                }
                .soukCard()

                VStack(spacing: 0) {
                    MenuRow(systemImage: "gearshape", title: i18n.t("nav.settings"), action: onOpenSettings)
                    // Mirrors the web navbar's own gating: only ADMIN sees this entry.
                    if user?.role == "ADMIN" {
                        divider
                        MenuRow(systemImage: "shield", title: i18n.t("nav.admin"), action: onOpenAdmin)
                    }
                }
                .soukCard()
            }
            .padding(Spacing.lg)
        }
        .navigationTitle(i18n.t("nav.account"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LanguageSwitcher()
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.soukmarBorder).frame(height: 1)
    }

    @ViewBuilder
    private func avatar(_ user: UserDto) -> some View {
        if let image = user.image, !image.isEmpty, let url = URL(string: image) {
            AsyncImage(url: url) { phase in
                if let loaded = phase.image {
                    loaded.resizable().scaledToFill()
                } else {
                    Color.soukmarSurfaceMuted
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.soukmarPrimary)
                .frame(width: 56, height: 56)
                .overlay(Text(String(user.name.prefix(1)).uppercased()).font(.title3.bold()).foregroundStyle(Color.white))
        }
    }
}

#Preview {
    HomeView(onLoggedOut: {})
}
