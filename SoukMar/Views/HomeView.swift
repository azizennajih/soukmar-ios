import SwiftUI

/// Mirrors soukmar-android's HomeScreen — greeting, search entry point, and
/// the categories grid, each category navigating into ListingsView filtered
/// by that category. Other TopAppBar entries from Android (chat, favorites,
/// notifications, profile menu, admin) land in their own later iOS phases.
struct HomeView: View {
    @State private var user: UserDto? = TokenStore.shared.cachedUser
    var onLoggedOut: () -> Void

    private enum Route: Hashable {
        case listings(category: String?)
        case listingForm(editId: String?)
        case chatList
        case myListings
    }
    // NavigationPath (type-erased), not a plain [Route] array: ListingsView
    // pushes a String (listing id) further down this same stack for
    // ListingDetailView, and a homogeneous typed array can only carry one
    // destination type for the whole stack.
    @State private var path = NavigationPath()

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let user {
                            Text("Bonjour, \(user.name) 👋")
                                .font(.title3.bold())
                                .padding(.horizontal)
                        }

                        Button {
                            path.append(Route.listings(category: nil))
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Rechercher une annonce...")
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Catégories").font(.headline).padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(CATEGORIES) { cat in
                                    Button {
                                        path.append(Route.listings(category: cat.value))
                                    } label: {
                                        VStack(spacing: 8) {
                                            Circle()
                                                .fill(cat.bg)
                                                .frame(width: 56, height: 56)
                                                .overlay(Text(cat.emoji).font(.title2))
                                            Text(cat.label)
                                                .font(.caption)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .padding(.bottom, 60)
                }

                Button {
                    path.append(Route.listingForm(editId: nil))
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.soukmarPrimary)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(20)
            }
            .navigationTitle("SoukMar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            path.append(Route.chatList)
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right")
                        }
                        Button {
                            path.append(Route.myListings)
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Se déconnecter") {
                        AuthRepository.shared.logout()
                        ChatSocketManager.shared.disconnect()
                        onLoggedOut()
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .listings(let category):
                    ListingsView(initialCategory: category)
                case .listingForm(let editId):
                    DeposerAnnonceView(editId: editId) { newListingId in
                        path.removeLast()
                        path.append(newListingId)
                    }
                case .chatList:
                    ChatListView()
                case .myListings:
                    MesAnnoncesView(
                        onOpenListing: { id in path.append(id) },
                        onEditListing: { id in path.append(Route.listingForm(editId: id)) },
                        onNewListing: { path.append(Route.listingForm(editId: nil)) }
                    )
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
                ListingDetailView(listingId: listingId) { conversationId in
                    path.append(ConversationRoute(conversationId: conversationId))
                }
            }
            .navigationDestination(for: ConversationRoute.self) { route in
                ChatView(conversationId: route.conversationId)
            }
            .task {
                if let refreshed = await AuthRepository.shared.me() {
                    user = refreshed
                }
            }
        }
    }
}

#Preview {
    HomeView(onLoggedOut: {})
}
