import Foundation

/// 공유 항아리 그룹 (public.groups). SwiftUI `Group` 뷰와 충돌 피하려 CatchGroup.
struct CatchGroup: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    let ownerId: UUID
    var inviteCode: String
    var shape: Int?
    var color: Int?
    var labelColor: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, shape, color
        case ownerId = "owner_id"
        case inviteCode = "invite_code"
        case labelColor = "label_color"
    }
}

/// 그룹 멤버 한 명 (group_members + 프로필 임베드)
struct GroupMember: Codable, Identifiable {
    let userId: UUID
    var role: String
    var profile: Profile?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case profile = "profiles"
    }
}
