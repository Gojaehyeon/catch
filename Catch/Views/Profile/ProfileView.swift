import SwiftUI

/// 타 유저(또는 본인) 프로필 — 내 프로필과 동일 레이아웃.
/// 고정 헤더(아바타 + 수집/팔로워/팔로잉 + 팔로우 버튼) + 그 아래 그 사람의 수집 잼(스티커+폴더, 읽기전용).
struct ProfileView: View {
    let userId: UUID
    var isSelf: Bool = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var jar: UserJarHolder

    init(userId: UUID, isSelf: Bool = false) {
        self.userId = userId
        self.isSelf = isSelf
        _jar = StateObject(wrappedValue: UserJarHolder(userId: userId))
    }

    @State private var profile: Profile?
    @State private var counts: ProfileCounts?
    @State private var following = false
    @State private var working = false
    @State private var confirmReport = false

    private let repo = ProfileRepository.shared
    private var username: String { profile?.username ?? "Catch 사용자" }

    var body: some View {
        VStack(spacing: 0) {
            header
            UserCollectionView(holder: jar)
        }
        .background(Color.black.ignoresSafeArea())
        // 스티커 상세 — 헤더까지 전부 덮도록 ProfileView 레벨 오버레이.
        .overlay {
            if let c = jar.focused {
                StickerDetailView(
                    catchId: c.id, imagePath: c.imagePath, ownerId: c.ownerId,
                    initialTitle: c.title, preloaded: jar.focusedImage,
                    onClose: { jar.dismissFocus() }
                )
                .ignoresSafeArea()
                .transition(.scale(scale: 0.9, anchor: .center).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: jar.focused != nil)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FollowListRoute.self) { FollowListView(userId: $0.userId, kind: $0.kind) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(username).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { jar.toggleGrid() } label: {
                    Image(systemName: jar.isGrid ? "circle.grid.3x3.fill" : "square.grid.2x2")
                        .foregroundStyle(.white)
                }
            }
            if !isSelf {
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { confirmReport = true } label: {
                            Label("신고", systemImage: "flag").foregroundStyle(.white)
                        }
                        Button {
                            Task { await ModerationRepository.shared.block(userId); dismiss() }
                        } label: { Label("차단", systemImage: "hand.raised").foregroundStyle(.white) }
                    } label: { Image(systemName: "ellipsis").foregroundStyle(.white) }
                }
            }
        }
        .alert("신고할까요?", isPresented: $confirmReport) {
            Button("취소", role: .cancel) {}
            Button("신고", role: .destructive) {
                Task { await ModerationRepository.shared.report(userId: userId, reason: "user_report"); dismiss() }
            }
        } message: { Text("부적절한 사용자로 신고해요.") }
        .task {
            profile = await repo.profile(id: userId)
            counts = await repo.counts(userId)
            if !isSelf { following = await repo.isFollowing(userId) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 22) {
                AvatarView(path: profile?.avatarUrl, fallbackText: username, size: 88)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))

                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        statContent("수집", counts?.collections)
                        statLink("팔로워", counts?.followers, .followers)
                        statLink("팔로잉", counts?.following, .following)
                    }
                    if !isSelf { followButton }
                }
            }

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio).font(.system(size: 13)).foregroundStyle(Theme.ink.opacity(0.85))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var followButton: some View {
        Button { Task { await toggleFollow() } } label: {
            Text(following ? "팔로잉" : "팔로우")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(following ? Theme.ink : .black)
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(following ? Theme.surface : Theme.lime,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .disabled(working)
    }

    private func statContent(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 3) {
            Text(value.map(String.init) ?? "—").font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func statLink(_ label: String, _ value: Int?, _ kind: FollowKind) -> some View {
        NavigationLink(value: FollowListRoute(userId: userId, kind: kind)) {
            statContent(label, value)
        }
        .buttonStyle(.plain)
    }

    private func toggleFollow() async {
        working = true
        if following {
            await repo.unfollow(userId); following = false
        } else {
            await repo.follow(userId); following = true
        }
        counts = await repo.counts(userId)
        working = false
    }
}
