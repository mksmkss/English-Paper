import Foundation
import PDFKit

enum PDFTextLocator {
    struct WordHit {
        let text: String
        let range: NSRange
        let bounds: CGRect
    }

    static func word(at index: Int, on page: PDFPage) -> WordHit? {
        guard let content = page.string, !content.isEmpty else { return nil }
        let characters = Array(content)
        guard index >= 0, index < characters.count else { return nil }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-'"))
        func isWordCharacter(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { allowed.contains($0) }
        }

        guard isWordCharacter(characters[index]) else { return nil }

        var start = index
        while start > 0, isWordCharacter(characters[start - 1]) {
            start -= 1
        }

        var end = index
        while end + 1 < characters.count, isWordCharacter(characters[end + 1]) {
            end += 1
        }

        let text = String(characters[start...end])
        let range = NSRange(location: start, length: end - start + 1)
        guard
            let selection = page.selection(for: range),
            let bounds = selection.selectionsByLine().reduce(into: CGRect.null, { partial, lineSelection in
                partial = partial.union(lineSelection.bounds(for: page))
            }).nullIfEmpty
        else {
            return nil
        }

        return WordHit(text: text, range: range, bounds: bounds)
    }

    static func contextSnippet(for selection: PDFSelection, on page: PDFPage) -> String? {
        guard
            let content = page.string,
            let selectedText = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
            !selectedText.isEmpty,
            let range = content.range(of: selectedText)
        else {
            return nil
        }

        let lowerBound = content.distance(from: content.startIndex, to: range.lowerBound)
        let upperBound = content.distance(from: content.startIndex, to: range.upperBound)
        let start = max(0, lowerBound - 30)
        let end = min(content.count, upperBound + 30)

        let startIndex = content.index(content.startIndex, offsetBy: start)
        let endIndex = content.index(content.startIndex, offsetBy: end)
        return String(content[startIndex..<endIndex]).replacingOccurrences(of: "\n", with: " ")
    }
}

private extension CGRect {
    var nullIfEmpty: CGRect? {
        isNull || isEmpty ? nil : self
    }
}
