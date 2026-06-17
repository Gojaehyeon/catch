import SwiftUI

/// 타 유저(또는 본인) 프로필 — 수집 항아리 + 카운트 + 팔로우.
struct ProfileView: View {
    let userId: UUID
    var isSelf: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile?
    @State private var counts: ProfileCounts?
    @State private var following = false
    @State private var working = false
    @State private var confirmReport = false
    private let repo = ProfileRepository.shared

    var body: some View {
        ZStack(alignment: .top) {
            JarView { try await CatchRepository.shared.loadUser(userId) }

            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isSelf {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { confirmReport = true } label: {
                            Label("신고", systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            Task { await ModerationRepository.shared.block(userId); dismiss() }
                        } label: { Label("차단", systemImage: "hand.raised") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
        }
        .alert("신고할까요?", isPresented: $confirmReport) {
            Button("취소", role: .cancel) {}
            Button("신고", role: .destructive) {
                Task { await ModerationRepository.shared.report(userId: userId, reason: "user_report"); dismiss() }
            }
        } message: { Text("부적절한 사용자로 신고해요.") }
        .task { await loadMeta() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(profile?.displayName ?? " ")
                .font(.headline).foregroundStyle(Theme.ink)
            Text("@\(profile?.username ?? "")")
                .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.55))

            HStack(spacing: 28) {
                stat("수집", counts?.collections)
                stat("팔로워", counts?.followers)
                stat("팔로잉", counts?.following)
            }

            if !isSelf {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Text(following ? "팔로잉 ✓" : "팔로우")
                        .font(.subheadline.bold())
                        .foregroundStyle(following ? Theme.ink.opacity(0.6) : .white)
                        .frame(width: 130, height: 38)
                        .background(following ? Color.white : Theme.coral, in: Capsule())
                        .shadow(color: (following ? Theme.ink : Theme.coral).opacity(0.25), radius: 6, y: 3)
                }
                .disabled(working)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.08), radius: 10, y: 5)
    }

    private func stat(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 2) {
            Text(value.map(String.init) ?? "—")
                .font(.headline).foregroundStyle(Theme.ink)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(Theme.ink.opacity(0.5))
        }
    }

    private func loadMeta() async {
        profile = await repo.profile(id: userId)
        counts = await repo.counts(userId)
        if !isSelf { following = await repo.isFollowing(userId) }
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
