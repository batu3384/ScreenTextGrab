import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit

struct ImportedPDFPage: Sendable {
    let pageIndex: Int
    let pageBounds: CGRect
    let image: CGImage
}

struct ImportedPDFRecognitionPage: Sendable {
    let pageIndex: Int
    let pageBounds: CGRect
    let result: OCRResult
}

enum PDFProcessingError: LocalizedError, Sendable {
    case unreadableDocument
    case emptyDocument
    case pageUnavailable(Int)
    case pageRenderFailed(Int)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableDocument:
            return L10n.pair("PDF dosyası açılamadı.", "The PDF file could not be opened.")
        case .emptyDocument:
            return L10n.pair("PDF içinde işlenecek sayfa bulunamadı.", "No pages were found to process in the PDF.")
        case .pageUnavailable(let pageNumber):
            return L10n.format("PDF sayfası okunamadı: %d.", "The PDF page could not be read: %d.", pageNumber)
        case .pageRenderFailed(let pageNumber):
            return L10n.format("PDF sayfası görsele dönüştürülemedi: %d.", "The PDF page could not be rendered: %d.", pageNumber)
        case .exportFailed(let reason):
            return L10n.format("Searchable PDF dışa aktarılamadı: %@", "Searchable PDF export failed: %@", reason)
        }
    }
}

enum PDFProcessingService {
    static func renderPages(from url: URL, maxDimension: CGFloat = 2_200) throws -> [ImportedPDFPage] {
        guard let document = PDFDocument(url: url) else {
            throw PDFProcessingError.unreadableDocument
        }

        guard document.pageCount > 0 else {
            throw PDFProcessingError.emptyDocument
        }

        return try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index) else {
                throw PDFProcessingError.pageUnavailable(index + 1)
            }

            let pageBounds = page.bounds(for: .mediaBox).standardized
            let longestEdge = max(pageBounds.width, pageBounds.height)
            let renderScale = max(1, min(3, maxDimension / max(longestEdge, 1)))

            let pixelWidth = max(1, Int(ceil(pageBounds.width * renderScale)))
            let pixelHeight = max(1, Int(ceil(pageBounds.height * renderScale)))

            guard let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw PDFProcessingError.pageRenderFailed(index + 1)
            }

            context.interpolationQuality = .high
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(pixelHeight))
            context.scaleBy(x: renderScale, y: -renderScale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()

            guard let image = context.makeImage() else {
                throw PDFProcessingError.pageRenderFailed(index + 1)
            }

            return ImportedPDFPage(
                pageIndex: index,
                pageBounds: pageBounds,
                image: image
            )
        }
    }

    static func suggestedSearchableOutputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let filename = sourceURL.deletingPathExtension().lastPathComponent + "-searchable.pdf"
        return directory.appendingPathComponent(filename)
    }

    static func exportSearchablePDF(
        from sourceURL: URL,
        recognizedPages: [ImportedPDFRecognitionPage],
        to destinationURL: URL
    ) throws {
        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFProcessingError.unreadableDocument
        }

        guard document.pageCount > 0 else {
            throw PDFProcessingError.emptyDocument
        }

        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard let consumer = CGDataConsumer(url: destinationURL as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw PDFProcessingError.exportFailed(L10n.pair("PDF hedef dosyası oluşturulamadı.", "The destination PDF file could not be created."))
        }

        let pagesByIndex = Dictionary(uniqueKeysWithValues: recognizedPages.map { ($0.pageIndex, $0) })

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw PDFProcessingError.pageUnavailable(pageIndex + 1)
            }

            let mediaBox = page.bounds(for: .mediaBox).standardized
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            page.draw(with: .mediaBox, to: context)

            if let recognizedPage = pagesByIndex[pageIndex] {
                drawInvisibleText(
                    blocks: recognizedPage.result.blocks,
                    pageBounds: recognizedPage.pageBounds,
                    in: context
                )
            }

            context.endPDFPage()
        }

        context.closePDF()
    }

    private static func drawInvisibleText(
        blocks: [OCRTextBlock],
        pageBounds: CGRect,
        in context: CGContext
    ) {
        guard !blocks.isEmpty else {
            return
        }

        for block in blocks {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }

            let rect = CGRect(
                x: pageBounds.width * block.boundingBox.minX,
                y: pageBounds.height * block.boundingBox.minY,
                width: pageBounds.width * block.boundingBox.width,
                height: pageBounds.height * block.boundingBox.height
            ).standardized

            guard rect.width >= 2, rect.height >= 2 else {
                continue
            }

            let fontSize = max(6, rect.height * 0.82)
            let fittedFont = fittedFont(for: text, baseSize: fontSize, targetWidth: rect.width)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fittedFont
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)

            context.saveGState()
            context.textMatrix = .identity
            context.setTextDrawingMode(.invisible)
            context.textPosition = CGPoint(x: rect.minX, y: rect.minY + max(0, (rect.height - fittedFont.pointSize) * 0.5))
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    private static func fittedFont(for text: String, baseSize: CGFloat, targetWidth: CGFloat) -> NSFont {
        var currentSize = baseSize
        var font = NSFont.systemFont(ofSize: currentSize)

        while currentSize > 4 {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
            let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])

            if bounds.width <= targetWidth || targetWidth <= 0 {
                return font
            }

            currentSize *= max(0.72, targetWidth / max(bounds.width, 1))
            font = NSFont.systemFont(ofSize: max(4, currentSize))
        }

        return font
    }
}
