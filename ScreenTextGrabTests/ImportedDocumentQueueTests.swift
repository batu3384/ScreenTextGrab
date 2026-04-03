import XCTest
@testable import ScreenTextGrab

final class ImportedDocumentQueueTests: XCTestCase {
    func testImportedDocumentQueueSerializesImportedFileCommandsUntilCaptureCompletes() {
        var queue = ImportedDocumentQueue()
        let imageCommand = AutomationCommand.imageFile(
            URL(fileURLWithPath: "/tmp/example.png"),
            AutomationCaptureOverrides()
        )
        let pdfCommand = AutomationCommand.pdfFile(
            URL(fileURLWithPath: "/tmp/example.pdf"),
            AutomationCaptureOverrides()
        )

        queue.enqueue([imageCommand, pdfCommand])

        let first = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(first, imageCommand)

        XCTAssertNil(queue.nextCommand(captureState: .preparing))

        queue.captureStateDidChange(.completed)

        let second = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(second, pdfCommand)
        XCTAssertTrue(queue.isEmpty)
    }

    func testImportedDocumentQueueReleasesImportedFileGateWhenDispatchFailsImmediately() {
        var queue = ImportedDocumentQueue()
        let imageCommand = AutomationCommand.imageFile(
            URL(fileURLWithPath: "/tmp/example.png"),
            AutomationCaptureOverrides()
        )
        let pdfCommand = AutomationCommand.pdfFile(
            URL(fileURLWithPath: "/tmp/example.pdf"),
            AutomationCaptureOverrides()
        )

        queue.enqueue([imageCommand, pdfCommand])

        let first = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(first, imageCommand)
        queue.markDispatchResult(for: imageCommand, startedBusyWork: false)

        let second = queue.nextCommand(captureState: .idle)
        XCTAssertEqual(second, pdfCommand)
    }
}
