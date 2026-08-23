import Foundation
import CryptoKit
import Security

enum ClipboardHistoryExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case text
    case markdown
    case json
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            return "TXT"
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        }
    }

    var subtitle: String {
        switch self {
        case .text:
            return L10n.pair("Okunabilir düz metin", "Readable plain text")
        case .markdown:
            return L10n.pair("Başlıklı doküman", "Structured document")
        case .json:
            return L10n.pair("Yapılandırılmış veri", "Structured data")
        case .csv:
            return L10n.pair("Spreadsheet uyumlu", "Spreadsheet-friendly")
        }
    }

    var fileExtension: String {
        rawValue
    }
}

enum ClipboardHistoryExportFormatStore {
    static let key = "screenTextGrab.historyExportFormat"

    static func load(defaults: UserDefaults = .standard) -> ClipboardHistoryExportFormat {
        guard let rawValue = defaults.string(forKey: key),
              let format = ClipboardHistoryExportFormat(rawValue: rawValue) else {
            return .markdown
        }

        return format
    }

    static func save(_ format: ClipboardHistoryExportFormat, defaults: UserDefaults = .standard) {
        defaults.set(format.rawValue, forKey: key)
    }
}

enum ClipboardHistoryStore {
    static let key = "screenTextGrab.copyHistory"
    static let maximumEntries = 25
    private static let embeddedKeyMaterialKey = "screenTextGrab.copyHistory.aesKey"
    private static let keychainService = "ScreenTextGrab.ClipboardHistory"
    private static let keychainAccount = "aes-gcm-v1"

    static func load(defaults: UserDefaults = .standard) -> [ClipboardHistoryEntry] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        if let plaintext = try? decrypt(data, defaults: defaults),
           let history = try? JSONDecoder().decode([ClipboardHistoryEntry].self, from: plaintext) {
            return Array(history.prefix(maximumEntries))
        }

        // Legacy plaintext UserDefaults payload — re-save encrypted.
        if let history = try? JSONDecoder().decode([ClipboardHistoryEntry].self, from: data) {
            let trimmed = Array(history.prefix(maximumEntries))
            save(trimmed, defaults: defaults)
            return trimmed
        }

        return []
    }

    static func save(_ history: [ClipboardHistoryEntry], defaults: UserDefaults = .standard) {
        let trimmed = Array(history.prefix(maximumEntries))
        guard let plaintext = try? JSONEncoder().encode(trimmed),
              let sealed = try? encrypt(plaintext, defaults: defaults) else {
            return
        }
        defaults.set(sealed, forKey: key)
    }

    private static func encrypt(_ plaintext: Data, defaults: UserDefaults) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey(defaults: defaults))
        guard let combined = sealed.combined else {
            throw CocoaError(.fileWriteUnknown)
        }
        return combined
    }

    private static func decrypt(_ data: Data, defaults: UserDefaults) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: symmetricKey(defaults: defaults))
    }

    private static func symmetricKey(defaults: UserDefaults) throws -> SymmetricKey {
        if ObjectIdentifier(defaults) != ObjectIdentifier(UserDefaults.standard) {
            if let existing = defaults.data(forKey: embeddedKeyMaterialKey), existing.count == 32 {
                return SymmetricKey(data: existing)
            }
            let material = try randomKeyMaterial()
            defaults.set(material, forKey: embeddedKeyMaterialKey)
            return SymmetricKey(data: material)
        }

        if let existing = loadKeychainKeyMaterial() {
            return SymmetricKey(data: existing)
        }

        let material = try randomKeyMaterial()
        try storeKeychainKeyMaterial(material)
        return SymmetricKey(data: material)
    }

    private static func randomKeyMaterial() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw CocoaError(.fileWriteUnknown)
        }
        return Data(bytes)
    }

    private static func loadKeychainKeyMaterial() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, data.count == 32 else {
            return nil
        }
        return data
    }

    private static func storeKeychainKeyMaterial(_ material: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = material
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    static func export(_ history: [ClipboardHistoryEntry], format: ClipboardHistoryExportFormat, generatedAt: Date = Date()) -> String {
        switch format {
        case .text:
            return exportText(history, generatedAt: generatedAt)
        case .markdown:
            return exportMarkdown(history, generatedAt: generatedAt)
        case .json:
            return exportJSON(history)
        case .csv:
            return exportCSV(history)
        }
    }

    static func orderedForDisplay(_ history: [ClipboardHistoryEntry]) -> [ClipboardHistoryEntry] {
        history.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func exportText(_ history: [ClipboardHistoryEntry], generatedAt: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "ScreenTextGrab Geçmişi",
            "Oluşturulma: \(formatter.string(from: generatedAt))",
            ""
        ]

        for (index, entry) in history.enumerated() {
            lines.append("#\(index + 1) - \(formatter.string(from: entry.date))")
            lines.append("Mod: \(entry.captureMode.title) | Çıktı: \(entry.outputPreset.title) | Tür: \(entry.contentKind.title) | Kaynak: \(entry.source?.displayName ?? "Bilinmiyor") | Sabit: \(entry.isPinned ? "Evet" : "Hayır")")
            lines.append(entry.text)
            if entry.effectiveRawText != entry.text {
                lines.append("Ham Metin: \(entry.effectiveRawText)")
            }
            lines.append("")
        }

        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportMarkdown(_ history: [ClipboardHistoryEntry], generatedAt: Date) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "# ScreenTextGrab Geçmişi",
            "",
            "- Oluşturulma: \(formatter.string(from: generatedAt))",
            "- Kayıt Sayısı: \(history.count)",
            ""
        ]

        for (index, entry) in history.enumerated() {
            lines.append("## \(index + 1). Kayıt")
            lines.append("")
            lines.append("- Tarih: \(formatter.string(from: entry.date))")
            lines.append("- Mod: \(entry.captureMode.title)")
            lines.append("- Çıktı: \(entry.outputPreset.title)")
            lines.append("- Tür: \(entry.contentKind.title)")
            lines.append("- Kaynak: \(entry.source?.displayName ?? "Bilinmiyor")")
            lines.append("- Sabit: \(entry.isPinned ? "Evet" : "Hayır")")
            lines.append("")
            lines.append("```text")
            lines.append(entry.text)
            lines.append("```")
            if entry.effectiveRawText != entry.text {
                lines.append("")
                lines.append("Ham İçerik")
                lines.append("")
                lines.append("```text")
                lines.append(entry.effectiveRawText)
                lines.append("```")
            }
            lines.append("")
        }

        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportJSON(_ history: [ClipboardHistoryEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func exportCSV(_ history: [ClipboardHistoryEntry]) -> String {
        var rows = [
            [
                "date",
                "mode",
                "output_preset",
                "content_kind",
                "is_pinned",
                "source_app",
                "source_bundle_id",
                "raw_text",
                "text"
            ].joined(separator: ",")
        ]

        for entry in history {
            rows.append([
                csvEscaped(ISO8601DateFormatter().string(from: entry.date)),
                csvEscaped(entry.captureMode.title),
                csvEscaped(entry.outputPreset.title),
                csvEscaped(entry.contentKind.title),
                csvEscaped(entry.isPinned ? "true" : "false"),
                csvEscaped(entry.source?.appName ?? ""),
                csvEscaped(entry.source?.bundleIdentifier ?? ""),
                csvEscaped(entry.effectiveRawText),
                csvEscaped(entry.text)
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    private static func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

