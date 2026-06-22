import SwiftUI

/// 그룹 생성/편집 시트 — 이름 + 모양 + 색(폴더와 동일 체계 재사용).
struct GroupEditView: View {
    var existing: CatchGroup?
    var onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var shape: Int
    @State private var color: Int
    @State private var working = false

    private let shapes = Array(FolderShape.allCases.indices)
    private let colors = Array(0..<8)

    init(existing: CatchGroup? = nil, onDone: @escaping () async -> Void) {
        self.existing = existing
        self.onDone = onDone
        _name = State(initialValue: existing?.name ?? "")
        _shape = State(initialValue: existing?.shape ?? 0)
        _color = State(initialValue: existing?.color ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                preview
                nameField
                shapeRow
                colorRow
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(existing == nil ? "새 그룹" : "그룹 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.tint(Theme.muted) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }.bold().tint(Theme.lime)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
                }
            }
        }
    }

    private var preview: some View {
        Image(uiImage: FolderShape.allCases[shape].image(
            name: name.isEmpty ? "그룹" : name,
            fill: FolderPalette.uiColor(color), label: FolderLabel.uiColor(fill: color)))
            .resizable().scaledToFit().frame(height: 140).padding(.top, 8)
    }

    private var nameField: some View {
        TextField("그룹 이름", text: $name)
            .font(.headline).foregroundStyle(Theme.ink).tint(Theme.lime)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: name) { _, v in if v.count > 20 { name = String(v.prefix(20)) } }
    }

    private var shapeRow: some View {
        HStack(spacing: 10) {
            ForEach(shapes, id: \.self) { i in
                Button { shape = i } label: {
                    Image(uiImage: FolderShape.allCases[i].image(name: "", fill: FolderPalette.uiColor(color), label: .clear))
                        .resizable().scaledToFit().frame(width: 40, height: 40)
                        .padding(6)
                        .background(shape == i ? Theme.surface : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach(colors, id: \.self) { i in
                Button { color = i } label: {
                    Circle().fill(FolderPalette.color(i)).frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(.white, lineWidth: color == i ? 3 : 0))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        working = true
        let n = name.trimmingCharacters(in: .whitespaces)
        Task {
            if let g = existing {
                await GroupRepository.shared.update(g.id, name: n, shape: shape, color: color, labelColor: nil)
            } else {
                _ = await GroupRepository.shared.create(name: n, shape: shape, color: color, labelColor: nil)
            }
            await onDone()
            dismiss()
        }
    }
}
