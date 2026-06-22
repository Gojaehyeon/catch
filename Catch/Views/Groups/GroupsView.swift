import SwiftUI

@MainActor
final class GroupsHolder: ObservableObject {
    @Published var groups: [CatchGroup] = []
    @Published var loading = true
    func reload() async {
        groups = await GroupRepository.shared.listMine()
        loading = false
    }
}

/// 그룹 탭 — 내가 속한 공유 항아리 그룹들. 생성/코드 참여/설정.
struct GroupsView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var holder = GroupsHolder()

    @State private var showSettings = false
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var joinError = false
    @State private var target: CatchGroup?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $target) { GroupJarView(group: $0) }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("그룹").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: { Image(systemName: "line.3.horizontal").foregroundStyle(.white) }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showJoin = true } label: { Image(systemName: "person.badge.plus").foregroundStyle(.white) }
                    }
                    if #available(iOS 26.0, *) { ToolbarSpacer(.fixed, placement: .topBarTrailing) }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreate = true } label: { Image(systemName: "plus").foregroundStyle(.white) }
                    }
                }
        }
        .task { await holder.reload() }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(auth) }
        .sheet(isPresented: $showCreate) { GroupEditView { await holder.reload() } }
        .alert("코드로 참여", isPresented: $showJoin) {
            TextField("초대 코드", text: $joinCode)
                .textInputAutocapitalization(.characters)
            Button("참여") { join() }
            Button("취소", role: .cancel) { joinCode = "" }
        } message: { Text("친구에게 받은 6자리 코드를 입력하세요.") }
        .alert("참여 실패", isPresented: $joinError) {
            Button("확인", role: .cancel) {}
        } message: { Text("코드를 다시 확인해 주세요.") }
    }

    @ViewBuilder private var content: some View {
        if holder.loading {
            CatchLoader()
        } else if holder.groups.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 16)], spacing: 20) {
                ForEach(holder.groups) { g in
                    Button { target = g } label: {
                        Image(uiImage: FolderShape.resolve(g.shape, id: g.id)
                            .image(name: g.name, fill: FolderPalette.uiColor(g.color),
                                   label: FolderLabel.uiColor(fill: g.color)))
                            .resizable().scaledToFit()
                            .frame(height: 116).frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 24)
            .padding(.bottom, deviceSafeAreaBottom + 96)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.lime.opacity(0.8))
            Text("아직 그룹이 없어요").font(.headline).foregroundStyle(Theme.ink)
            Text("그룹을 만들어 친구와 함께 스티커를 모아보세요").font(.subheadline)
                .foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button { showCreate = true } label: {
                    Label("그룹 만들기", systemImage: "plus")
                        .font(.subheadline.bold()).foregroundStyle(.black)
                        .padding(.horizontal, 18).frame(height: 44).background(Theme.lime, in: Capsule())
                }
                Button { showJoin = true } label: {
                    Label("코드로 참여", systemImage: "person.badge.plus")
                        .font(.subheadline.bold()).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 18).frame(height: 44).background(Theme.surface, in: Capsule())
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
    }

    private func join() {
        let code = joinCode.trimmingCharacters(in: .whitespaces)
        joinCode = ""
        guard !code.isEmpty else { return }
        Task {
            if let g = await GroupRepository.shared.join(code: code) {
                await holder.reload()
                target = g
            } else {
                joinError = true
            }
        }
    }
}
