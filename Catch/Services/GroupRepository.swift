import Foundation
import Supabase

@MainActor
final class GroupRepository {
    static let shared = GroupRepository()

    private struct CreateParams: Encodable { let p_name: String; let p_shape: Int?; let p_color: Int?; let p_label_color: Int? }
    private struct JoinParams: Encodable { let code: String }

    /// 내가 속한 그룹들(RLS가 멤버 그룹만 노출).
    func listMine() async -> [CatchGroup] {
        (try? await Supa.client.from("groups").select()
            .order("created_at", ascending: true).execute().value) ?? []
    }

    /// 그룹 생성(초대 코드 자동 + 본인 owner 멤버십). create_group RPC.
    func create(name: String, shape: Int?, color: Int?, labelColor: Int?) async -> CatchGroup? {
        try? await Supa.client.rpc("create_group",
            params: CreateParams(p_name: name, p_shape: shape, p_color: color, p_label_color: labelColor))
            .execute().value
    }

    /// 초대 코드로 가입. join_group RPC.
    func join(code: String) async -> CatchGroup? {
        try? await Supa.client.rpc("join_group", params: JoinParams(code: code.uppercased()))
            .execute().value
    }

    func leave(_ groupId: UUID) async {
        guard let uid = try? await Supa.client.auth.session.user.id else { return }
        _ = try? await Supa.client.from("group_members").delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: uid.uuidString).execute()
    }

    func delete(_ groupId: UUID) async {
        _ = try? await Supa.client.from("groups").delete()
            .eq("id", value: groupId.uuidString).execute()
    }

    private struct GroupUpdate: Encodable { let name: String; let shape: Int?; let color: Int?; let label_color: Int? }
    func update(_ id: UUID, name: String, shape: Int?, color: Int?, labelColor: Int?) async {
        _ = try? await Supa.client.from("groups")
            .update(GroupUpdate(name: name, shape: shape, color: color, label_color: labelColor))
            .eq("id", value: id.uuidString).execute()
    }

    func members(_ groupId: UUID) async -> [GroupMember] {
        (try? await Supa.client.from("group_members")
            .select("user_id, role, profiles(id,username,display_name,avatar_url,bio)")
            .eq("group_id", value: groupId.uuidString).execute().value) ?? []
    }

    /// 그룹에 담긴 모든 스티커(멤버 누구 것이든). RLS가 멤버만 허용.
    func catches(_ groupId: UUID) async -> [CloudCatch] {
        (try? await Supa.client.from("catches").select()
            .eq("group_id", value: groupId.uuidString)
            .order("caught_at", ascending: true).execute().value) ?? []
    }
}
