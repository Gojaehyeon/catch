import SwiftUI

/// 프로필 탭 — 내 프로필(카운트) + 친구들 피드.
struct ProfilePageView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var counts: ProfileCounts?
    @State private var rows: [FeedRow] = []
    @State private var loading = false
    @State private var reachedEnd = false
    @State private var didLoad = false
    @State private var showSettings = false
    @State private var showSearch = false

    private let feed = FeedRepository.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if rows.isEmpty && didLoad {
                        emptyFeed.padding(.top, 40)
                    } else {
                        ForEach(rows) { row in
                            FeedCard(row: row).onAppear { maybeLoadMore(row) }
                        }
                        if loading { CatchLoader().padding() }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationDestination(for: UUID.self) { ProfileView(userId: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .task { if !didLoad { await reload() } }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(auth) }
        .sheet(isPresented: $showSearch) { UserSearchView() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.grape)
            Text(auth.profile?.displayName ?? "Catch 사용자")
                .font(.title3.bold()).foregroundStyle(Theme.ink)
            Text("@\(auth.profile?.username ?? "")")
                .font(.mono(13)).foregroundStyle(Theme.muted)

            HStack(spacing: 0) {
                stat("collected", counts?.collections)
                stat("followers", counts?.followers)
                stat("following", counts?.following)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 3) {
            Text(value.map(String.init) ?? "—").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(label).font(.mono(10)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyFeed: some View {
        VStack(spacing: 8) {
            Text("👀").font(.system(size: 44))
            Text("친구를 팔로우하면\n여기 친구들 수집이 떠요")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button { showSearch = true } label: {
                Label("find friends", systemImage: "magnifyingglass")
                    .font(.subheadline.bold()).foregroundStyle(.black)
                    .padding(.horizontal, 20).frame(height: 44)
                    .background(Theme.coral, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func reload() async {
        if let id = auth.profile?.id { counts = await ProfileRepository.shared.counts(id) }
        loading = true
        let page = await feed.page(after: nil)
        rows = page
        reachedEnd = page.count < 20
        loading = false
        didLoad = true
    }

    private func maybeLoadMore(_ row: FeedRow) {
        guard !loading, !reachedEnd, row.id == rows.last?.id else { return }
        Task {
            loading = true
            let page = await feed.page(after: rows.last)
            rows.append(contentsOf: page)
            reachedEnd = page.count < 20
            loading = false
        }
    }
}
