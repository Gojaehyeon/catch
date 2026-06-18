import UIKit
import Supabase

enum CatchError: Error { case encodingFailed, notAuthed }

/// 로컬-퍼스트 캐치 저장.
/// 촬영 → 로컬에 즉시 저장하고 바로 항아리에 표시(즐거움 우선) → 백그라운드로 Supabase 동기화.
@MainActor
final class CatchRepository {
    static let shared = CatchRepository()

    private let bucket = "stickers"
    private let fm = FileManager.default

    private var cacheDir: URL {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("catchimages", isDirectory: true)
        if !fm.fileExists(atPath: base.path) {
            try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }
    private func cacheURL(_ path: String) -> URL {
        cacheDir.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_"))
    }

    // 미동기화(pending) 매니페스트
    private var pendingURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("pending.json")
    }
    private func loadPending() -> [CloudCatch] {
        guard let data = try? Data(contentsOf: pendingURL),
              let list = try? JSONDecoder().decode([CloudCatch].self, from: data) else { return [] }
        return list
    }
    private func savePending(_ list: [CloudCatch]) {
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: pendingURL, options: .atomic) }
    }
    private func addPending(_ c: CloudCatch) { var l = loadPending(); l.append(c); savePending(l) }
    private func removePending(_ id: UUID) { savePending(loadPending().filter { $0.id != id }) }

    // MARK: - 로컬 즉시 저장 (촬영 직후)
    @discardableResult
    func capture(image: UIImage) async throws -> CloudCatch {
        let uid = try await Supa.client.auth.session.user.id
        let id = UUID()
        let uidStr = uid.uuidString.lowercased()
        let idStr = id.uuidString.lowercased()

        let normalized = image.orientationNormalized().resized(maxDimension: 1024).trimmingTransparentPixels()
        let body = normalized.resized(maxDimension: 256)
        guard let png = normalized.pngData(), let bodyPng = body.pngData() else { throw CatchError.encodingFailed }

        let imagePath = "catches/\(uidStr)/\(idStr).png"
        let bodyPath = "catches/\(uidStr)/\(idStr)_body.png"
        // 로컬 캐시에 즉시 기록(표시·오프라인·동기화 소스)
        try? png.write(to: cacheURL(imagePath))
        try? bodyPng.write(to: cacheURL(bodyPath))

        let cloud = CloudCatch(id: id, ownerId: uid, folderId: nil,
                               imagePath: imagePath, bodyPath: bodyPath, title: nil, isPublic: true)
        addPending(cloud)
        Task { await self.sync(cloud) }   // 백그라운드 업로드
        return cloud
    }

    // MARK: - 백그라운드 동기화
    private func sync(_ c: CloudCatch) async {
        guard let png = try? Data(contentsOf: cacheURL(c.imagePath)) else { return }
        let opts = FileOptions(contentType: "image/png", upsert: true)
        do {
            try await Supa.client.storage.from(bucket).upload(c.imagePath, data: png, options: opts)
            if let bp = c.bodyPath, let bodyPng = try? Data(contentsOf: cacheURL(bp)) {
                try? await Supa.client.storage.from(bucket).upload(bp, data: bodyPng, options: opts)
            }
            let payload = CatchInsert(id: c.id.uuidString.lowercased(),
                                      owner_id: c.ownerId.uuidString.lowercased(),
                                      image_path: c.imagePath, body_path: c.bodyPath ?? "")
            try await Supa.client.from("catches").upsert(payload).execute()
            removePending(c.id)
        } catch {
            // 실패 시 pending 유지 → 다음 실행/로드 때 재시도
        }
    }

    func retryPending() async {
        for c in loadPending() { await sync(c) }
    }

    // MARK: - Load (클라우드 + 로컬 pending 병합)
    func loadMine(folderId: UUID? = nil) async throws -> [CloudCatch] {
        let uid = try await Supa.client.auth.session.user.id
        let base = Supa.client.from("catches").select().eq("owner_id", value: uid.uuidString)
        let cloud: [CloudCatch]
        if let folderId {
            cloud = (try? await base.eq("folder_id", value: folderId.uuidString)
                .order("caught_at", ascending: true).execute().value) ?? []
        } else {
            cloud = (try? await base.order("caught_at", ascending: true).execute().value) ?? []
        }
        let cloudIds = Set(cloud.map { $0.id })
        let pending = loadPending().filter { p in
            !cloudIds.contains(p.id) && (folderId == nil || p.folderId == folderId)
        }
        Task { await retryPending() }
        return cloud + pending
    }

    func loadUser(_ userId: UUID) async throws -> [CloudCatch] {
        try await Supa.client.from("catches").select()
            .eq("owner_id", value: userId.uuidString)
            .order("caught_at", ascending: true).execute().value
    }

    // MARK: - Images (로컬 캐시 우선)
    func image(at path: String) async -> UIImage? {
        let url = cacheURL(path)
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { return img }
        guard let data = try? await Supa.client.storage.from(bucket).download(path: path) else { return nil }
        try? data.write(to: url)
        return UIImage(data: data)
    }
    func displayImage(for c: CloudCatch) async -> UIImage? { await image(at: c.imagePath) }
    func bodyImage(for c: CloudCatch) async -> UIImage? {
        if let bp = c.bodyPath, let img = await image(at: bp) { return img }
        return await displayImage(for: c)
    }

    // MARK: - Delete
    func delete(_ c: CloudCatch) async {
        removePending(c.id)
        try? await Supa.client.from("catches").delete().eq("id", value: c.id.uuidString).execute()
        var paths = [c.imagePath]
        if let bp = c.bodyPath { paths.append(bp) }
        _ = try? await Supa.client.storage.from(bucket).remove(paths: paths)
        for p in paths { try? fm.removeItem(at: cacheURL(p)) }
    }
}
