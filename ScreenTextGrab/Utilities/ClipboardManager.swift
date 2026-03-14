import AppKit
import ImageIO

enum ClipboardTargetProfile: String, Sendable, Equatable {
    case generic
    case spreadsheet
    case wordProcessor

    static func resolve(for bundleIdentifier: String?) -> ClipboardTargetProfile {
        guard let bundleIdentifier else {
            return .generic
        }

        switch bundleIdentifier {
        case "com.microsoft.Excel", "com.apple.iWork.Numbers":
            return .spreadsheet
        case "com.microsoft.Word", "com.apple.iWork.Pages":
            return .wordProcessor
        default:
            return .generic
        }
    }
}

struct ClipboardPayload: Sendable, Equatable {
    let string: String
    let html: String?
    let tabularText: String?
    let targetProfile: ClipboardTargetProfile

    init(
        string: String,
        html: String? = nil,
        tabularText: String? = nil,
        targetProfile: ClipboardTargetProfile = .generic
    ) {
        self.string = string
        self.html = html
        self.tabularText = tabularText
        self.targetProfile = targetProfile
    }
}

protocol ClipboardProviding {
    func copyToClipboard(_ payload: ClipboardPayload) -> ClipboardWriteResult
    func readFromClipboard() -> String?
    func readImageFromClipboard() -> CGImage?
    func showCopyNotification(text: String, on displayFrame: CGRect?)
}

extension ClipboardProviding {
    func copyToClipboard(_ text: String) -> ClipboardWriteResult {
        copyToClipboard(ClipboardPayload(string: text))
    }
}

final class ClipboardManager: ClipboardProviding {
    static let commaSeparatedValuesType = NSPasteboard.PasteboardType("public.comma-separated-values-text")

    func copyToClipboard(_ payload: ClipboardPayload) -> ClipboardWriteResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = Self.pasteboardItem(for: payload)
        let writeSucceeded = pasteboard.writeObjects([item])

        guard writeSucceeded else {
            STGLog.clipboard.error("Pasteboard write failed")
            return .failedWrite
        }

        guard let readback = Self.readbackString(from: pasteboard, payload: payload),
              Self.normalizedLineEndings(in: readback) == Self.normalizedLineEndings(in: Self.readbackExpectation(for: payload)) else {
            STGLog.clipboard.error("Pasteboard readback mismatch")
            return .failedReadback
        }

        STGLog.clipboard.info("Pasteboard write verified")
        return .success
    }

    func readFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string) ??
            NSPasteboard.general.string(forType: .tabularText)
    }

    func readImageFromClipboard() -> CGImage? {
        let pasteboard = NSPasteboard.general

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let cgImage = Self.cgImage(from: image) {
            return cgImage
        }

        guard let data = pasteboard.data(forType: .tiff),
              let image = NSImage(data: data) else {
            return nil
        }

        return Self.cgImage(from: image)
    }

    static func pasteboardItem(for payload: ClipboardPayload) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        let plainText = plainTextForPasteboard(from: payload)

        if let tabularText = payload.tabularText {
            populateTablePasteboardItem(item, payload: payload, tabularText: tabularText)
        } else {
            populateRichTextPasteboardItem(item, payload: payload, plainText: plainText)
            item.setString(plainText, forType: .string)
        }

        return item
    }

    func showCopyNotification(text: String, on displayFrame: CGRect?) {
        DispatchQueue.main.async {
            Self.showFloatingNotification(text: text, on: displayFrame)
        }
    }

    private static var activeNotifications: [ObjectIdentifier: NSWindow] = [:]

    private static func showFloatingNotification(text: String, on displayFrame: CGRect?) {
        let previewText = text.count > 80 ? String(text.prefix(80)) + "..." : text

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = true

        let visualEffect = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12

        let stackView = NSStackView(frame: visualEffect.bounds.insetBy(dx: 16, dy: 12))
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4

        let titleLabel = NSTextField(labelWithString: "✅ Metin kopyalandı!")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let textLabel = NSTextField(labelWithString: previewText)
        textLabel.font = NSFont.systemFont(ofSize: 11)
        textLabel.textColor = .secondaryLabelColor
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 2

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(textLabel)

        visualEffect.addSubview(stackView)
        window.contentView = visualEffect

        let targetFrame = targetVisibleFrame(for: displayFrame)
        let x = targetFrame.maxX - window.frame.width - 20
        let y = targetFrame.maxY - window.frame.height - 20
        window.setFrameOrigin(NSPoint(x: x, y: y))

        window.alphaValue = 0
        retain(window)
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
                release(window)
            })
        }
    }

    private static func targetVisibleFrame(for displayFrame: CGRect?) -> CGRect {
        if let displayFrame,
           let matchedScreen = NSScreen.screens.first(where: {
               $0.frame.equalTo(displayFrame) || $0.frame.intersection(displayFrame).equalTo(displayFrame)
           }) {
            return matchedScreen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ??
            NSScreen.screens.first?.visibleFrame ??
            CGRect(x: 40, y: 40, width: 1200, height: 800)
    }

    private static func retain(_ window: NSWindow) {
        activeNotifications[ObjectIdentifier(window)] = window
    }

    private static func release(_ window: NSWindow) {
        activeNotifications.removeValue(forKey: ObjectIdentifier(window))
    }

    static func plainTextForPasteboard(from payload: ClipboardPayload) -> String {
        if let tabularText = payload.tabularText {
            return officeTableTextForPasteboard(tabularText)
        }

        return payload.string
    }

    static func readbackExpectation(for payload: ClipboardPayload) -> String {
        if let tabularText = payload.tabularText {
            return officeTableTextForPasteboard(tabularText)
        }

        return plainTextForPasteboard(from: payload)
    }

    static func officeTableTextForPasteboard(_ text: String) -> String {
        normalizedLineEndings(in: text)
            .components(separatedBy: "\n")
            .joined(separator: "\r\n")
    }

    static func normalizedLineEndings(in text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func readbackString(from pasteboard: NSPasteboard, payload: ClipboardPayload) -> String? {
        if payload.tabularText != nil {
            return pasteboard.string(forType: .tabularText) ??
                pasteboard.string(forType: .string)
        }

        return pasteboard.string(forType: .string)
    }

    static func csvText(fromTSV text: String) -> String? {
        let rows = normalizedLineEndings(in: text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { row in
                row
                    .split(separator: "\t", omittingEmptySubsequences: false)
                    .map(String.init)
            }

        guard rows.contains(where: { $0.count > 1 }) else {
            return nil
        }

        return rows.map { row in
            row.map(csvCell).joined(separator: ",")
        }
        .joined(separator: "\r\n")
    }

    private static func csvCell(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }

        return escaped
    }

    private static func populateTablePasteboardItem(
        _ item: NSPasteboardItem,
        payload: ClipboardPayload,
        tabularText: String
    ) {
        let officeTableText = officeTableTextForPasteboard(tabularText)
        let html = payload.html
        let rtf = tableRTFData(fromTSV: tabularText) ?? html.flatMap(rtfData(forHTML:))

        switch payload.targetProfile {
        case .spreadsheet:
            item.setString(officeTableText, forType: .tabularText)
            if let csvText = csvText(fromTSV: tabularText) {
                item.setString(csvText, forType: commaSeparatedValuesType)
            }
            if let html {
                item.setString(html, forType: .html)
            }

        case .wordProcessor:
            if let rtf {
                item.setData(rtf, forType: .rtf)
            }
            if let html {
                item.setString(html, forType: .html)
            }
            item.setString(officeTableText, forType: .tabularText)

        case .generic:
            if let html {
                item.setString(html, forType: .html)
            }
            if let rtf {
                item.setData(rtf, forType: .rtf)
            }
            item.setString(officeTableText, forType: .tabularText)
            if let csvText = csvText(fromTSV: tabularText) {
                item.setString(csvText, forType: commaSeparatedValuesType)
            }
        }
    }

    private static func populateRichTextPasteboardItem(
        _ item: NSPasteboardItem,
        payload: ClipboardPayload,
        plainText: String
    ) {
        guard let html = payload.html else {
            return
        }

        let rtf = rtfData(forHTML: html)

        switch payload.targetProfile {
        case .wordProcessor:
            if let rtf {
                item.setData(rtf, forType: .rtf)
            }
            item.setString(html, forType: .html)

        case .generic, .spreadsheet:
            item.setString(html, forType: .html)
            if let rtf {
                item.setData(rtf, forType: .rtf)
            }
        }
    }

    static func rtfData(forHTML html: String) -> Data? {
        guard let htmlData = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                  data: htmlData,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              ) else {
            return nil
        }

        return try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func tableRTFData(fromTSV text: String) -> Data? {
        guard let layout = OfficeTableLayout.fromTSV(normalizedLineEndings(in: text)),
              layout.rows.count >= 2 else {
            return nil
        }

        let width = layout.width
        guard width >= 2 else {
            return nil
        }

        let baseCellWidth = 2200
        var rtf = "{\\rtf1\\ansi\\deff0\n"
        rtf += "{\\fonttbl{\\f0\\fnil -apple-system;}}\n"
        rtf += "\\viewkind4\\uc1\\pard\\f0\\fs24\n"

        for rowIndex in layout.rows.indices {
            let row = layout.physicalCells(forRowAt: rowIndex)
            rtf += "\\trowd\\trgaph108\\trleft0\n"

            for cellIndex in 0..<width {
                let cellRight = baseCellWidth * (cellIndex + 1)
                let isHeaderRow = rowIndex == 0
                rtf += "\\clbrdrt\\brdrs\\brdrw12"
                rtf += "\\clbrdrl\\brdrs\\brdrw12"
                rtf += "\\clbrdrb\\brdrs\\brdrw12"
                rtf += "\\clbrdrr\\brdrs\\brdrw12"
                switch row[cellIndex].state {
                case .mergeStart:
                    rtf += "\\clmgf"
                case .mergeContinuation:
                    rtf += "\\clmrg"
                case .normal:
                    break
                }
                if isHeaderRow {
                    rtf += "\\clcbpat8"
                }
                rtf += "\\cellx\(cellRight)\n"
            }

            for value in row {
                switch value.state {
                case .mergeContinuation:
                    rtf += "\\intbl \\cell\n"
                case .mergeStart, .normal:
                    let escaped = rtfEscapedCell(value.value)
                    if rowIndex == 0 {
                        rtf += "\\intbl\\b \(escaped)\\b0\\cell\n"
                    } else {
                        rtf += "\\intbl \(escaped)\\cell\n"
                    }
                }
            }

            rtf += "\\row\n"
        }

        rtf += "}"
        return rtf.data(using: .utf8)
    }

    private static func rtfEscapedCell(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            switch scalar.value {
            case 92:
                return "\\\\"
            case 123:
                return "\\{"
            case 125:
                return "\\}"
            case 10, 13:
                return "\\line "
            case 32...126:
                return String(scalar)
            default:
                return "\\u\(Int32(bitPattern: UInt32(scalar.value)))?"
            }
        }
        .joined()
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        guard let tiffData = image.tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}
