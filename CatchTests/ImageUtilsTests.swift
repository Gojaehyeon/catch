import XCTest
import UIKit
@testable import Catch

final class ImageUtilsTests: XCTestCase {

    /// 지정 크기의 단색 불투명 이미지.
    private func solidImage(_ size: CGSize, color: UIColor = .red) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 투명 캔버스 가운데에 불투명 사각형을 그린 이미지.
    private func paddedImage(canvas: CGSize, opaqueRect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            UIColor.green.setFill()
            ctx.fill(opaqueRect)
        }
    }

    func testResizedDownscalesPreservingAspect() {
        let img = solidImage(CGSize(width: 1000, height: 500))
        let out = img.resized(maxDimension: 100)
        XCTAssertEqual(out.size.width, 100, accuracy: 0.5)
        XCTAssertEqual(out.size.height, 50, accuracy: 0.5)
    }

    func testResizedLeavesSmallImageUntouched() {
        let img = solidImage(CGSize(width: 80, height: 40))
        let out = img.resized(maxDimension: 100)
        XCTAssertEqual(out.size.width, 80, accuracy: 0.5)
        XCTAssertEqual(out.size.height, 40, accuracy: 0.5)
    }

    func testTrimmingTransparentPixelsCropsToOpaqueBounds() {
        let canvas = CGSize(width: 100, height: 100)
        let opaque = CGRect(x: 30, y: 20, width: 40, height: 50)
        let img = paddedImage(canvas: canvas, opaqueRect: opaque)

        let trimmed = img.trimmingTransparentPixels()

        // 투명 여백이 잘려 불투명 영역 크기에 가까워야 한다(안티앨리어싱 여유 ±2px).
        XCTAssertEqual(trimmed.size.width, opaque.width, accuracy: 2)
        XCTAssertEqual(trimmed.size.height, opaque.height, accuracy: 2)
        XCTAssertLessThan(trimmed.size.width, canvas.width)
    }

    func testTrimmingFullyTransparentReturnsOriginal() {
        // 불투명 픽셀이 없으면 원본을 그대로 반환(크래시 없이).
        let img = paddedImage(canvas: CGSize(width: 50, height: 50), opaqueRect: .zero)
        let trimmed = img.trimmingTransparentPixels()
        XCTAssertEqual(trimmed.size, img.size)
    }

    func testLimeStickerBorderedGrowsImage() {
        let img = solidImage(CGSize(width: 200, height: 200))
        let result = img.limeStickerBordered()
        // 테두리가 더해지므로 표시 이미지는 working보다 커야 한다.
        XCTAssertGreaterThan(result.bordered.size.width, result.working.size.width)
        XCTAssertGreaterThan(result.bordered.size.height, result.working.size.height)
    }
}
