import XCTest
@testable import Catch

/// 촬영 결과 표시를 구동하는 상태 계약 고정.
/// (실제 셔터→스캔 전환 버그는 페이저 렌더링 문제라 단위 테스트로는 못 잡지만,
///  여기서 isCapturing/reset 의미가 깨지면 컨테이너 오버레이 표시가 어긋난다.)
@MainActor
final class CameraFlowModelTests: XCTestCase {

    func testFreshModelIsNotCapturing() {
        let model = CameraFlowModel()
        XCTAssertNil(model.captured)
        XCTAssertFalse(model.isCapturing)
    }

    func testCapturedDrivesIsCapturing() {
        let model = CameraFlowModel()
        model.captured = UIImage()
        XCTAssertTrue(model.isCapturing, "captured가 있으면 컨테이너가 스캔 화면을 띄워야 한다")
    }

    func testResetClearsCapturedAndCutout() {
        let model = CameraFlowModel()
        model.captured = UIImage()
        model.cutout = UIImage()

        model.reset()

        XCTAssertNil(model.captured)
        XCTAssertNil(model.cutout)
        XCTAssertFalse(model.isCapturing)
    }
}
