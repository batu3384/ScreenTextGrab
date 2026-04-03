import Foundation
import UniformTypeIdentifiers

enum ImportedDocumentRouter {
    static func resolve(_ url: URL) -> ImportedDocumentRoute? {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.isFileURL else {
            return nil
        }

        let type = resolvedType(for: standardizedURL)
        if type?.conforms(to: .pdf) == true {
            return .pdf(standardizedURL)
        }
        if type?.conforms(to: .image) == true {
            return .image(standardizedURL)
        }

        return nil
    }

    private static func resolvedType(for url: URL) -> UTType? {
        let metadataType: UTType?
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]) {
            metadataType = values.contentType
        } else {
            metadataType = nil
        }

        if let metadataType,
           metadataType.conforms(to: .pdf) || metadataType.conforms(to: .image) {
            return metadataType
        }

        if let metadataType,
           metadataType != .data,
           metadataType != .content,
           metadataType != .item {
            return metadataType
        }

        if !url.pathExtension.isEmpty,
           let extensionType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            return extensionType
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return metadataType
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 16) else {
            return metadataType
        }

        if data.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) {
            return .pdf
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return .png
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        }
        if data.starts(with: [0x42, 0x4D]) {
            return .bmp
        }
        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return .tiff
        }

        return metadataType
    }
}
