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

}
