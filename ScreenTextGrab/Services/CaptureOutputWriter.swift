import AppKit
import Foundation

@MainActor
final class CaptureOutputWriter {
    private let appState: AppState
    private let clipboardService: ClipboardProviding

    init(appState: AppState, clipboardService: ClipboardProviding) {
        self.appState = appState
        self.clipboardService = clipboardService
    }

    func copyText(_ text: String, captureMode: CaptureMode) -> ClipboardWriteResult {
        guard !text.isEmpty else {
            return .failedWrite
        }

        let result = clipboardService.copyToClipboard(text)
        switch result {
        case .success:
            appState.recordCopiedText(text, captureMode: captureMode)
            clipboardService.showCopyNotification(text: text, on: nil)
            appState.statusMessage = "✅ Tekrar kopyalandı"
        case .failedWrite, .failedReadback:
            appState.statusMessage = CapturePipelineError.clipboardFailed(result: result).errorDescription ?? "⚠️ Kopyalama başarısız"
        }

        return result
    }

    func copyCapturedText(
        rawText: String,
        captureMode: CaptureMode,
        contentKind: ClipboardHistoryEntry.ContentKind,
        source: ClipboardHistoryEntry.SourceContext?,
        outputPreset: CaptureOutputPreset,
        targetBundleIdentifier: String? = nil,
        ocrConfidence: Float? = nil,
        notificationDisplayFrame: CGRect? = nil,
        successStatusMessage: String? = nil
    ) -> ClipboardWriteResult {
        let payload = CaptureOutputFormatter.clipboardPayload(
            rawText: rawText,
            captureMode: captureMode,
            contentKind: contentKind,
            preset: outputPreset,
            source: source,
            targetBundleIdentifier: targetBundleIdentifier
        )
        let formattedText = payload.string

        guard !formattedText.isEmpty else {
            return .failedWrite
        }

        let result = clipboardService.copyToClipboard(payload)
        switch result {
        case .success:
            appState.recordCopiedText(
                formattedText,
                captureMode: captureMode,
                outputPreset: outputPreset,
                contentKind: contentKind,
                rawText: rawText,
                ocrConfidence: ocrConfidence,
                source: source
            )
            clipboardService.showCopyNotification(text: formattedText, on: notificationDisplayFrame)
            appState.statusMessage = successStatusMessage ?? "✅ \(outputPreset.title) çıktısı kopyalandı"
        case .failedWrite, .failedReadback:
            appState.statusMessage = CapturePipelineError.clipboardFailed(result: result).errorDescription ?? "⚠️ Kopyalama başarısız"
        }

        return result
    }
}
