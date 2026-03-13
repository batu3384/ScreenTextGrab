import XCTest
import CoreGraphics
@testable import ScreenTextGrab

final class OCRServiceTests: XCTestCase {
    func testDetectTableGuideSeparatorsFindsInnerVerticalGridLines() {
        let image = makeGridImage(
            width: 240,
            height: 180,
            verticalLines: [2, 80, 160, 238],
            horizontalLines: [2, 60, 120, 178]
        )

        let guides = OCRService.detectTableGuideSeparators(in: image)

        XCTAssertEqual(guides.count, 2)
        XCTAssertEqual(guides[0], 80.5 / 240.0, accuracy: 0.03)
        XCTAssertEqual(guides[1], 160.5 / 240.0, accuracy: 0.03)
    }

    private func makeGridImage(
        width: Int,
        height: Int,
        verticalLines: [Int],
        horizontalLines: [Int]
    ) -> CGImage {
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        for x in verticalLines {
            context.fill(CGRect(x: x, y: 0, width: 2, height: height))
        }

        for y in horizontalLines {
            context.fill(CGRect(x: 0, y: y, width: width, height: 2))
        }

        // Simulate a few text areas so the test image looks closer to a spreadsheet.
        let sampleCells = [
            CGRect(x: 18, y: 134, width: 26, height: 10),
            CGRect(x: 100, y: 134, width: 22, height: 10),
            CGRect(x: 180, y: 134, width: 20, height: 10),
            CGRect(x: 22, y: 74, width: 20, height: 10),
            CGRect(x: 104, y: 74, width: 26, height: 10),
            CGRect(x: 182, y: 74, width: 18, height: 10)
        ]

        for rect in sampleCells {
            context.fill(rect)
        }

        return context.makeImage()!
    }
}
