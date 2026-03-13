import XCTest
import CoreImage
@testable import ScreenTextGrab

final class BarcodeDetectionTests: XCTestCase {
    func testQRCodePayloadIsDetected() async throws {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data("https://example.com/pay".utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")

        let transform = CGAffineTransform(scaleX: 14, y: 14)
        let image = filter?.outputImage?.transformed(by: transform)
        XCTAssertNotNil(image)

        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(image!, from: image!.extent)
        XCTAssertNotNil(cgImage)

        let service = OCRService()
        let barcode = try await service.detectBarcode(in: cgImage!)

        XCTAssertEqual(barcode?.payload, "https://example.com/pay")
        XCTAssertEqual(barcode?.displayName, "QR kodu")
    }
}
