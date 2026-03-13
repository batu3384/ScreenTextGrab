import Foundation

enum WatchCopyBehavior: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case wholeResult
    case newLinesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wholeResult:
            return "Tam Sonuç"
        case .newLinesOnly:
            return "Sadece Yeni Satırlar"
        }
    }

    var detail: String {
        switch self {
        case .wholeResult:
            return "İzlenen alan değiştiğinde tüm metni yeniden kopyalar."
        case .newLinesOnly:
            return "Önceki sonuca göre sadece yeni gelen satırları kopyalar."
        }
    }
}

struct WatchConfiguration: Codable, Equatable, Sendable {
    var copyBehavior: WatchCopyBehavior
    var regexFilter: String

    static let defaultValue = WatchConfiguration(copyBehavior: .wholeResult, regexFilter: "")

    var summary: String {
        if regexFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return copyBehavior.detail
        }

        return "\(copyBehavior.title) • Regex: \(regexFilter)"
    }
}

enum WatchConfigurationStore {
    static let key = "screenTextGrab.watchConfiguration"

    static func load(defaults: UserDefaults = .standard) -> WatchConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(WatchConfiguration.self, from: data) else {
            return .defaultValue
        }

        return configuration
    }

    static func save(_ configuration: WatchConfiguration, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

struct AppCaptureProfile: Identifiable, Equatable, Codable, Sendable {
    let bundleIdentifier: String
    let appName: String
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let ocrLanguageSelection: OCRLanguageSelection

    var id: String { bundleIdentifier }

    var summary: String {
        "\(captureMode.title) • \(outputPreset.title) • \(ocrLanguageSelection.summary)"
    }
}

enum AppCaptureProfileStore {
    static let key = "screenTextGrab.appCaptureProfiles"
    static let recommendedProfiles: [AppCaptureProfile] = [
        AppCaptureProfile(
            bundleIdentifier: "com.microsoft.Excel",
            appName: "Microsoft Excel",
            captureMode: .table,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.apple.iWork.Numbers",
            appName: "Numbers",
            captureMode: .table,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.microsoft.Word",
            appName: "Microsoft Word",
            captureMode: .standard,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        ),
        AppCaptureProfile(
            bundleIdentifier: "com.apple.iWork.Pages",
            appName: "Pages",
            captureMode: .standard,
            outputPreset: .office,
            ocrLanguageSelection: .defaultValue
        )
    ]

    static func load(defaults: UserDefaults = .standard) -> [AppCaptureProfile] {
        guard defaults.object(forKey: key) != nil else {
            return sortedProfiles(recommendedProfiles)
        }

        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([AppCaptureProfile].self, from: data) else {
            return sortedProfiles(recommendedProfiles)
        }

        return sortedProfiles(profiles)
    }

    static func save(_ profiles: [AppCaptureProfile], defaults: UserDefaults = .standard) {
        let sorted = sortedProfiles(profiles)
        guard let data = try? JSONEncoder().encode(sorted) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func sortedProfiles(_ profiles: [AppCaptureProfile]) -> [AppCaptureProfile] {
        profiles.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }
}

struct CaptureSessionConfiguration: Equatable, Sendable {
    let captureMode: CaptureMode
    let outputPreset: CaptureOutputPreset
    let ocrLanguageSelection: OCRLanguageSelection
    let profileName: String?
}
