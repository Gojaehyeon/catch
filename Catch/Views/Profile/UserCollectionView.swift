import SwiftUI
import SpriteKit

/// 타 유저 수집(스티커+폴더) 읽기전용 물리 잼 + 그리드 전환.
@MainActor
final class UserJarHolder: ObservableObject {
    let scene = StickerScene(size: CGSize(width: 390, height: 844))
    @Published var isLoading = true
    @Published var isEmpty = false
    @Published var isGrid = false
    @Published var currentFolder: Folder?
    @Published private(set) var folders: [Folder] = []
    @Published var focused: CloudCatch?
    @Published var focusedImage: UIImage?

    let userId: UUID
    private var allCatches: [CloudCatch] = []
    private var byId: [UUID: CloudCatch] = [:]
    private let repo = CatchRepository.shared
    private var loaded = false

    /// 현재 보고 있는 레벨(루트/폴더)의 스티커 — 그리드용.
    var gridCatches: [CloudCatch] { allCatches.filter { $0.folderId == currentFolder?.id } }

    init(userId: UUID) {
        self.userId = userId
        scene.scaleMode = .resizeFill
        scene.readOnly = true
        scene.plainBackground = true
        scene.onTapCatch = { [weak self] id in Task { await self?.focus(id) } }
        scene.onOpenFolder = { [weak self] id in Task { await self?.enterFolder(id) } }
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        loaded = true
        folders = await FolderRepository.shared.listUser(userId)
        allCatches = ((try? await repo.loadUser(userId)) ?? [])
        isLoading = false
        await reload(folderId: nil)
    }

    func toggleGrid() {
        isGrid.toggle()
        scene.isPaused = isGrid   // 그리드 중엔 물리 정지(그리드가 위를 덮음)
    }

    func enterFolder(_ id: UUID) async {
        currentFolder = folders.first { $0.id == id }
        await reload(folderId: id)
    }

    func exitToRoot() async {
        currentFolder = nil
        await reload(folderId: nil)
    }

    private func reload(folderId: UUID?) async {
        scene.clearAll(); byId.removeAll()
        if folderId == nil {
            for f in folders {
                scene.addFolder(id: f.id, name: f.name, shape: f.shape, color: f.color, labelColor: f.labelColor)
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
        for c in allCatches where c.folderId == folderId {
            byId[c.id] = c
            try? await Task.sleep(nanoseconds: 60_000_000)
            await spawn(c)
        }
        isEmpty = folders.isEmpty && allCatches.isEmpty
    }

    private func spawn(_ c: CloudCatch) async {
        guard let body = await repo.bodyImage(for: c) else { return }
        let prepared = await Task.detached(priority: .userInitiated) { body.whiteStickerBordered() }.value
        scene.addCatch(id: c.id, bordered: prepared.bordered, working: prepared.working, body: body)
    }

    func focus(_ id: UUID) async {
        guard let c = byId[id] ?? allCatches.first(where: { $0.id == id }),
              let img = await repo.displayImage(for: c) else { return }
        // 테두리 생성(블러+드로잉)은 백그라운드 — 트랜지션 끊김 방지.
        let bordered = await Task.detached(priority: .userInitiated) { img.whiteStickerBordered().bordered }.value
        focusedImage = bordered
        scene.isPaused = true   // 오버레이 뒤 물리 정지 → 부드러운 전환
        focused = c
    }

    func dismissFocus() {
        focused = nil; focusedImage = nil
        if !isGrid { scene.isPaused = false }   // 그리드 모드면 계속 정지 유지
    }
}

struct UserCollectionView: View {
    @ObservedObject var holder: UserJarHolder

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: holder.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea(edges: .bottom)

            if holder.isGrid { gridOverlay.transition(.opacity) }

            if holder.isLoading {
                CatchLoader().padding(.top, 80)
            } else if holder.isEmpty {
                Text("아직 수집이 없어요 🫧")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink.opacity(0.5)).padding(.top, 80)
            }

            // 폴더 안: 상단에 폴더명 + 뒤로가기.
            if let folder = holder.currentFolder {
                HStack(spacing: 10) {
                    Button { Task { await holder.exitToRoot() } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white).frame(width: 38, height: 38)
                            .liquidGlass(Circle(), interactive: true)
                    }
                    Text(folder.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: holder.isGrid)
        .task {
            holder.scene.toolbarBarrier = (width: 226, height: 72, bottomMargin: deviceSafeAreaBottom + 6)
            await holder.loadIfNeeded()
        }
        // 스티커 상세 오버레이는 ProfileView 레벨에서(헤더까지 전부 덮도록).
    }

    // MARK: - 그리드(스크롤뷰)

    private var gridOverlay: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 14) {
                if holder.currentFolder == nil {
                    ForEach(holder.folders) { f in
                        Button { Task { await holder.enterFolder(f.id) } } label: {
                            Image(uiImage: FolderShape.resolve(f.shape, id: f.id)
                                .image(name: f.name, fill: FolderPalette.uiColor(f.color),
                                       label: FolderLabel.uiColor(fill: f.color)))
                                .resizable().scaledToFit().padding(8)
                                .frame(height: 116).frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(holder.gridCatches) { c in
                    Button { Task { await holder.focus(c.id) } } label: {
                        BorderedStickerImage(path: c.bodyPath ?? c.imagePath)
                            .padding(10).frame(height: 116).frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
            .padding(.bottom, deviceSafeAreaBottom + 96)
        }
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
    }
}
