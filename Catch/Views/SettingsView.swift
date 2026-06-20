import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false
    @State private var working = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    developerIntro
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    Button {
                        working = true
                        Task { await auth.signOut(); working = false; dismiss() }
                    } label: { Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right").foregroundStyle(.white) }

                    Button {
                        confirmDelete = true
                    } label: { Label("회원 탈퇴", systemImage: "trash").foregroundStyle(.white) }
                }
            }
            .navigationTitle("Catch!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .disabled(working)
            .alert("회원 탈퇴할까요?", isPresented: $confirmDelete) {
                Button("취소", role: .cancel) {}
                Button("탈퇴", role: .destructive) {
                    working = true
                    Task { await auth.deleteAccount(); working = false; dismiss() }
                }
            } message: {
                Text("프로필과 모든 수집이 영구 삭제되며 되돌릴 수 없어요.")
            }
        }
    }

    // MARK: - 개발자 소개

    private var developerIntro: some View {
        VStack(spacing: 12) {
            Image("DevPhoto")
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

            Text("Gojaehyun").font(.title2.bold()).foregroundStyle(.white)
            Text("CEO @tntlabs\nProject Manager @Savetokip")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                linkButton("GitHub", icon: "chevron.left.forwardslash.chevron.right",
                           url: "https://github.com/Gojaehyeon")
                linkButton("Instagram", icon: "play.rectangle.fill",
                           url: "https://www.instagram.com/reel/DZJ4CA6vyLz/?igsh=MTR5aHF5eTVxNHpxcA==")
            }
            .padding(.top, 4)
        }
    }

    private func linkButton(_ title: String, icon: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { openURL(u) }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
