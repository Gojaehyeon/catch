import XCTest
@testable import Catch

final class ModelCodingTests: XCTestCase {

    func testCloudCatchDecodesSnakeCaseKeys() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "folder_id": null,
          "image_path": "catches/u/i.png",
          "body_path": "catches/u/i_body.png",
          "title": null,
          "is_public": true
        }
        """.data(using: .utf8)!

        let c = try JSONDecoder().decode(CloudCatch.self, from: json)
        XCTAssertEqual(c.imagePath, "catches/u/i.png")
        XCTAssertEqual(c.bodyPath, "catches/u/i_body.png")
        XCTAssertNil(c.folderId)
        XCTAssertTrue(c.isPublic)
    }

    func testFeedRowDecodesOwnerAndLiked() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "image_path": "p.png",
          "body_path": null,
          "like_count": 7,
          "caught_at": "2026-06-18T10:00:00Z",
          "username": "alice",
          "display_name": "Alice",
          "liked": true
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(FeedRow.self, from: json)
        XCTAssertEqual(row.likeCount, 7)
        XCTAssertEqual(row.username, "alice")
        XCTAssertEqual(row.displayName, "Alice")
        XCTAssertTrue(row.liked)
        XCTAssertNil(row.bodyPath)
    }

    func testProfileHasUsername() throws {
        func profile(_ name: String?) throws -> Profile {
            let dict: [String: Any] = name.map { ["id": "33333333-3333-3333-3333-333333333333", "username": $0] }
                ?? ["id": "33333333-3333-3333-3333-333333333333"]
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Profile.self, from: data)
        }

        XCTAssertTrue(try profile("alice").hasUsername)
        XCTAssertFalse(try profile("").hasUsername)
        XCTAssertFalse(try profile(nil).hasUsername)
    }
}
