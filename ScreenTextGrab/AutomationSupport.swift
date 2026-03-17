import CoreGraphics
import Foundation

struct RecentCaptureSelection: Equatable, Sendable {
    let screenRect: CGRect
    let preferredDisplayID: CGDirectDisplayID?
    let source: ClipboardHistoryEntry.SourceContext?
    let sessionConfiguration: CaptureSessionConfiguration
}

struct AutomationCaptureOverrides: Equatable, Sendable {
    var captureMode: CaptureMode?
    var outputPreset: CaptureOutputPreset?
    var languagePreferences: [OCRLanguagePreference]?
    var automaticDetection: Bool?

    init(
        captureMode: CaptureMode? = nil,
        outputPreset: CaptureOutputPreset? = nil,
        languagePreferences: [OCRLanguagePreference]? = nil,
        automaticDetection: Bool? = nil
    ) {
        self.captureMode = captureMode
        self.outputPreset = outputPreset
        self.languagePreferences = languagePreferences
        self.automaticDetection = automaticDetection
    }

    var isEmpty: Bool {
        captureMode == nil &&
            outputPreset == nil &&
            languagePreferences == nil &&
            automaticDetection == nil
    }

    func applying(to base: CaptureSessionConfiguration) -> CaptureSessionConfiguration {
        var languageSelection = base.ocrLanguageSelection

        if let languagePreferences {
            languageSelection = OCRLanguageSelection(
                automaticDetection: automaticDetection ?? languageSelection.automaticDetection,
                languages: languagePreferences
            )
        } else if let automaticDetection {
            languageSelection = languageSelection.settingAutomaticDetection(automaticDetection)
        }

        return CaptureSessionConfiguration(
            captureMode: captureMode ?? base.captureMode,
            outputPreset: outputPreset ?? base.outputPreset,
            ocrLanguageSelection: languageSelection,
            profileName: base.profileName
        )
    }
}

enum AutomationCommand: Equatable, Sendable {
    case capture(AutomationCaptureOverrides)
    case repeatLast(AutomationCaptureOverrides)
    case savedRegion(String, AutomationCaptureOverrides)
    case activeSnippet
    case snippet(String)
    case snippetCollection(String)
    case clipboardImage(AutomationCaptureOverrides)
    case imageFile(URL, AutomationCaptureOverrides)
    case pdfFile(URL, AutomationCaptureOverrides)
    case searchablePDF(URL, URL?, AutomationCaptureOverrides)

    var isImportedFileCommand: Bool {
        switch self {
        case .imageFile, .pdfFile:
            return true
        default:
            return false
        }
    }

    init?(arguments: [String]) {
        let normalizedArguments = Array(arguments.dropFirst())
        let wantsCapture = normalizedArguments.contains("--capture")
        let wantsRepeatLast = normalizedArguments.contains("--repeat-last")
        let wantsSavedRegion = normalizedArguments.contains("--saved-region")
        let wantsActiveSnippet = normalizedArguments.contains("--active-snippet")
        let wantsSnippet = normalizedArguments.contains("--snippet")
        let wantsSnippetCollection = normalizedArguments.contains("--snippet-collection")
        let wantsClipboardImage = normalizedArguments.contains("--clipboard-image")
        let wantsImageFile = normalizedArguments.contains("--image-file")
        let wantsPDFFile = normalizedArguments.contains("--pdf-file")
        let wantsSearchablePDF = normalizedArguments.contains("--pdf-searchable")

        let requestedActions = [wantsCapture, wantsRepeatLast, wantsSavedRegion, wantsActiveSnippet, wantsSnippet, wantsSnippetCollection, wantsClipboardImage, wantsImageFile, wantsPDFFile, wantsSearchablePDF]
            .filter { $0 }
            .count

        guard requestedActions > 0 else {
            return nil
        }

        guard requestedActions == 1 else {
            return nil
        }

        let overrides = Self.parseOverrides(
            modeValue: Self.value(after: "--mode", in: normalizedArguments),
            outputValue: Self.value(after: "--output", in: normalizedArguments),
            languagesValue: Self.value(after: "--languages", in: normalizedArguments),
            automaticDetectionValue: Self.value(after: "--ocr-auto", in: normalizedArguments) ??
                Self.value(after: "--auto-language", in: normalizedArguments)
        )

        let pathValue = Self.value(after: "--path", in: normalizedArguments)
        let destinationValue = Self.value(after: "--destination", in: normalizedArguments)
        let nameValue = Self.value(after: "--name", in: normalizedArguments)

        switch (wantsCapture, wantsRepeatLast, wantsSavedRegion, wantsActiveSnippet, wantsSnippet, wantsSnippetCollection, wantsClipboardImage, wantsImageFile, wantsPDFFile, wantsSearchablePDF) {
        case (true, false, false, false, false, false, false, false, false, false):
            self = .capture(overrides)
        case (false, true, false, false, false, false, false, false, false, false):
            self = .repeatLast(overrides)
        case (false, false, true, false, false, false, false, false, false, false):
            guard let nameValue, !nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .savedRegion(nameValue, overrides)
        case (false, false, false, true, false, false, false, false, false, false):
            self = .activeSnippet
        case (false, false, false, false, true, false, false, false, false, false):
            guard let nameValue, !nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .snippet(nameValue)
        case (false, false, false, false, false, true, false, false, false, false):
            guard let nameValue, !nameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .snippetCollection(nameValue)
        case (false, false, false, false, false, false, true, false, false, false):
            self = .clipboardImage(overrides)
        case (false, false, false, false, false, false, false, true, false, false):
            guard let pathValue, !pathValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .imageFile(URL(fileURLWithPath: pathValue), overrides)
        case (false, false, false, false, false, false, false, false, true, false):
            guard let pathValue, !pathValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .pdfFile(URL(fileURLWithPath: pathValue), overrides)
        case (false, false, false, false, false, false, false, false, false, true):
            guard let pathValue, !pathValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let destinationURL = destinationValue.flatMap {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : URL(fileURLWithPath: $0)
            }
            self = .searchablePDF(URL(fileURLWithPath: pathValue), destinationURL, overrides)
        default:
            return nil
        }
    }

    init?(url: URL) {
        guard let scheme = url.scheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              ["stg", "screentextgrab"].contains(scheme) else {
            return nil
        }

        let action = Self.action(from: url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let overrides = Self.parseOverrides(
            modeValue: queryItems.firstValue(for: ["mode"]),
            outputValue: queryItems.firstValue(for: ["output", "preset"]),
            languagesValue: queryItems.firstValue(for: ["languages", "langs"]),
            automaticDetectionValue: queryItems.firstValue(for: ["ocr-auto", "ocr_auto", "auto-language"])
        )
        let filePath = queryItems.firstValue(for: ["path", "file"])
        let destinationPath = queryItems.firstValue(for: ["destination", "output-file", "output_file"])
        let regionName = queryItems.firstValue(for: ["name", "region"])

        switch action {
        case "capture":
            self = .capture(overrides)
        case "repeat-last", "repeat_last", "recapture":
            self = .repeatLast(overrides)
        case "saved-region", "saved_region", "region":
            guard let regionName, !regionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .savedRegion(regionName, overrides)
        case "active-snippet", "active_snippet", "current-snippet", "current_snippet":
            self = .activeSnippet
        case "snippet", "saved-snippet", "saved_snippet":
            guard let regionName, !regionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .snippet(regionName)
        case "snippet-collection", "snippet_collection", "collection", "saved-collection", "saved_collection":
            guard let regionName, !regionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .snippetCollection(regionName)
        case "clipboard-image", "clipboard_image", "clipboard":
            self = .clipboardImage(overrides)
        case "image-file", "image_file", "file-image", "file_image":
            guard let filePath, !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .imageFile(URL(fileURLWithPath: filePath), overrides)
        case "pdf-file", "pdf_file", "file-pdf", "file_pdf", "pdf":
            guard let filePath, !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            self = .pdfFile(URL(fileURLWithPath: filePath), overrides)
        case "searchable-pdf", "searchable_pdf", "pdf-searchable":
            guard let filePath, !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let destinationURL = destinationPath.flatMap {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : URL(fileURLWithPath: $0)
            }
            self = .searchablePDF(URL(fileURLWithPath: filePath), destinationURL, overrides)
        default:
            return nil
        }
    }

    init?(incomingURL: URL) {
        if let command = AutomationCommand(url: incomingURL) {
            self = command
            return
        }

        guard incomingURL.isFileURL else {
            return nil
        }

        switch ImportedDocumentRouter.resolve(incomingURL) {
        case .image(let imageURL):
            self = .imageFile(imageURL, AutomationCaptureOverrides())
        case .pdf(let pdfURL):
            self = .pdfFile(pdfURL, AutomationCaptureOverrides())
        case nil:
            return nil
        }
    }

    static func resolveIncomingURLs(_ urls: [URL]) -> IncomingAutomationResolution {
        let commands = urls.compactMap(AutomationCommand.init(incomingURL:))

        guard !commands.isEmpty else {
            return .unsupported
        }

        return .commands(commands)
    }

    private static func action(from url: URL) -> String {
        if let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines),
           !host.isEmpty {
            return host.lowercased()
        }

        return url.pathComponents
            .drop { $0 == "/" }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }

        return arguments[index + 1]
    }

    private static func parseOverrides(
        modeValue: String?,
        outputValue: String?,
        languagesValue: String?,
        automaticDetectionValue: String?
    ) -> AutomationCaptureOverrides {
        AutomationCaptureOverrides(
            captureMode: modeValue.flatMap(CaptureMode.automationValue),
            outputPreset: outputValue.flatMap(CaptureOutputPreset.automationValue),
            languagePreferences: languagesValue.flatMap(Self.languagePreferences(from:)),
            automaticDetection: automaticDetectionValue.flatMap(Self.booleanValue(from:))
        )
    }

    private static func languagePreferences(from value: String) -> [OCRLanguagePreference]? {
        let parts = value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(OCRLanguagePreference.automationValue)

        return parts.isEmpty ? nil : parts
    }

    private static func booleanValue(from value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on", "enabled":
            return true
        case "0", "false", "no", "off", "disabled":
            return false
        default:
            return nil
        }
    }
}

enum IncomingAutomationResolution: Equatable {
    case commands([AutomationCommand])
    case unsupported
}

struct AutomationCommandQueue {
    private(set) var pendingCommands: [AutomationCommand] = []
    private(set) var importedFileCommandInFlight = false

    var isEmpty: Bool {
        pendingCommands.isEmpty
    }

    mutating func enqueue(_ commands: [AutomationCommand]) {
        pendingCommands.append(contentsOf: commands)
    }

    mutating func nextCommand(captureState: CaptureState) -> AutomationCommand? {
        guard !pendingCommands.isEmpty, !captureState.isBusy else {
            return nil
        }

        if pendingCommands[0].isImportedFileCommand, importedFileCommandInFlight {
            return nil
        }

        let command = pendingCommands.removeFirst()
        if command.isImportedFileCommand {
            importedFileCommandInFlight = true
        }
        return command
    }

    mutating func markDispatchResult(for command: AutomationCommand, startedBusyWork: Bool) {
        guard command.isImportedFileCommand, !startedBusyWork else {
            return
        }

        importedFileCommandInFlight = false
    }

    mutating func captureStateDidChange(_ captureState: CaptureState) {
        if !captureState.isBusy {
            importedFileCommandInFlight = false
        }
    }
}

enum AutomationURLBuilder {
    static func capture(overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()) -> URL? {
        commandURL(path: "capture", overrides: overrides)
    }

    static func repeatLast(overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()) -> URL? {
        commandURL(path: "repeat-last", overrides: overrides)
    }

    static func savedRegion(
        name: String,
        overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()
    ) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return commandURL(path: "saved-region", overrides: overrides, extraQueryItems: [
            URLQueryItem(name: "name", value: name)
        ])
    }

    static func snippet(name: String) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return commandURL(path: "snippet", overrides: AutomationCaptureOverrides(), extraQueryItems: [
            URLQueryItem(name: "name", value: name)
        ])
    }

    static func activeSnippet() -> URL? {
        commandURL(path: "active-snippet", overrides: AutomationCaptureOverrides())
    }

    static func snippetCollection(name: String) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return commandURL(path: "snippet-collection", overrides: AutomationCaptureOverrides(), extraQueryItems: [
            URLQueryItem(name: "name", value: name)
        ])
    }

    static func clipboardImage(overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()) -> URL? {
        commandURL(path: "clipboard-image", overrides: overrides)
    }

    static func imageFile(
        path: String,
        overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()
    ) -> URL? {
        commandURL(path: "image-file", overrides: overrides, extraQueryItems: [
            URLQueryItem(name: "path", value: path)
        ])
    }

    static func pdfFile(
        path: String,
        overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()
    ) -> URL? {
        commandURL(path: "pdf-file", overrides: overrides, extraQueryItems: [
            URLQueryItem(name: "path", value: path)
        ])
    }

    static func searchablePDF(
        path: String,
        destination: String? = nil,
        overrides: AutomationCaptureOverrides = AutomationCaptureOverrides()
    ) -> URL? {
        var extraQueryItems = [URLQueryItem(name: "path", value: path)]
        if let destination {
            extraQueryItems.append(URLQueryItem(name: "destination", value: destination))
        }
        return commandURL(path: "searchable-pdf", overrides: overrides, extraQueryItems: extraQueryItems)
    }

    private static func commandURL(
        path: String,
        overrides: AutomationCaptureOverrides,
        extraQueryItems: [URLQueryItem] = []
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "stg"
        components.host = path

        var queryItems: [URLQueryItem] = extraQueryItems

        if let captureMode = overrides.captureMode {
            queryItems.append(URLQueryItem(name: "mode", value: captureMode.rawValue))
        }

        if let outputPreset = overrides.outputPreset {
            queryItems.append(URLQueryItem(name: "output", value: outputPreset.rawValue))
        }

        if let languagePreferences = overrides.languagePreferences, !languagePreferences.isEmpty {
            queryItems.append(
                URLQueryItem(
                    name: "languages",
                    value: languagePreferences.map(\.shortAutomationValue).joined(separator: ",")
                )
            )
        }

        if let automaticDetection = overrides.automaticDetection {
            queryItems.append(
                URLQueryItem(
                    name: "ocr-auto",
                    value: automaticDetection ? "true" : "false"
                )
            )
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}

private extension Array where Element == URLQueryItem {
    func firstValue(for names: [String]) -> String? {
        let normalizedNames = Set(names.map { $0.lowercased() })
        return first { item in
            normalizedNames.contains(item.name.lowercased())
        }?.value
    }
}

private extension CaptureMode {
    static func automationValue(_ rawValue: String) -> CaptureMode? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "standard", "default", "text":
            return .standard
        case "subtitle", "subtitles", "caption", "captions":
            return .subtitle
        case "code", "terminal":
            return .code
        case "table", "spreadsheet":
            return .table
        default:
            return nil
        }
    }
}

private extension CaptureOutputPreset {
    static func automationValue(_ rawValue: String) -> CaptureOutputPreset? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "smart", "auto":
            return .smart
        case "plain", "plain-text", "plaintext", "text":
            return .plainText
        case "cleaned", "clean":
            return .cleaned
        case "office":
            return .office
        case "markdown", "md":
            return .markdown
        case "json":
            return .json
        default:
            return nil
        }
    }
}

private extension OCRLanguagePreference {
    static func automationValue(_ rawValue: String) -> OCRLanguagePreference? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "tr", "tr-tr", "turkish", "turkce":
            return .turkish
        case "en", "en-us", "english":
            return .english
        case "de", "de-de", "german", "deutsch":
            return .german
        case "fr", "fr-fr", "french", "francais":
            return .french
        case "es", "es-es", "spanish", "espanol":
            return .spanish
        case "it", "it-it", "italian", "italiano":
            return .italian
        case "pt", "pt-br", "portuguese", "portugues":
            return .portuguese
        default:
            return nil
        }
    }

    var shortAutomationValue: String {
        switch self {
        case .turkish:
            return "tr"
        case .english:
            return "en"
        case .german:
            return "de"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        case .italian:
            return "it"
        case .portuguese:
            return "pt"
        }
    }
}
