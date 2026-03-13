import Foundation

enum WatchTextFilter {
    static func payload(
        from currentText: String,
        previousText: String?,
        configuration: WatchConfiguration
    ) -> String? {
        guard let filteredCurrent = filteredText(currentText, configuration: configuration) else {
            return nil
        }

        switch configuration.copyBehavior {
        case .wholeResult:
            return filteredCurrent
        case .newLinesOnly:
            guard let previousText,
                  let filteredPrevious = filteredText(previousText, configuration: configuration),
                  !filteredPrevious.isEmpty else {
                return filteredCurrent
            }

            if filteredCurrent == filteredPrevious {
                return nil
            }

            if filteredCurrent.hasPrefix(filteredPrevious) {
                let suffix = String(filteredCurrent.dropFirst(filteredPrevious.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return suffix.isEmpty ? nil : suffix
            }

            let previousLines = Set(
                filteredPrevious
                    .split(separator: "\n")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            )
            let newLines = filteredCurrent
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !previousLines.contains($0) }

            guard !newLines.isEmpty else {
                return nil
            }

            return newLines.joined(separator: "\n")
        }
    }

    static func filteredText(_ text: String, configuration: WatchConfiguration) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let pattern = configuration.regexFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else {
            return trimmed
        }

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return trimmed
        }

        let range = NSRange(location: 0, length: trimmed.utf16.count)
        let matches = regex.matches(in: trimmed, options: [], range: range).compactMap { match -> String? in
            guard let swiftRange = Range(match.range, in: trimmed) else {
                return nil
            }

            return String(trimmed[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }

        guard !matches.isEmpty else {
            return nil
        }

        return matches.joined(separator: "\n")
    }
}
