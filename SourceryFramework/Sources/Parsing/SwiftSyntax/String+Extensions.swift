import Foundation

extension StringProtocol {
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines) // TODO: verify
    }
}

extension String {
    var nilIfEmpty: String? {
        if isEmpty {
            return nil
        }

        return self
    }

    var nilIfNotValidParameterName: String? {
        if isEmpty {
            return nil
        }

        if self == "_" {
            return nil
        }

        return self
    }

    func countInstances(of stringToFind: String) -> Int {
        guard !stringToFind.isEmpty else { return 0 }
        var count = 0
        var searchRange: Range<String.Index>?
        while let foundRange = range(of: stringToFind, options: [], range: searchRange) {
            count += 1
            searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: endIndex))
        }
        return count
    }
}
