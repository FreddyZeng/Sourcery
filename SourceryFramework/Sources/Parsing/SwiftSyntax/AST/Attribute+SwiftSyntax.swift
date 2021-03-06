import Foundation
import SourceryRuntime
import SwiftSyntax

extension Attribute {
    // TODO: modifiers are not attributes but for now keep it the same as old Sourcery version treated both the same, to be changed in next update
    convenience init(_ modifier: Modifier) {
        let name = modifier.name
        if let detail = modifier.detail {
            self.init(name: name, arguments: ["0": detail as NSString], description: "\(name)(\(detail))")
        } else {
            self.init(name: name, description: name)
        }
    }

    convenience init(_ attribute: AttributeSyntax) {
        var arguments = [String: NSObject]()
        attribute.argument?.description
          .split(separator: ",")
          .enumerated()
          .forEach { (idx, part) in
              let components = part.split(separator: ":", maxSplits: 1)
              switch components.count {
              case 2:
                  arguments[components[0].trimmed] = components[1].replacingOccurrences(of: "\"", with: "").trimmed as NSString
              case 1:
                  arguments["\(idx)"] = components[0].replacingOccurrences(of: "\"", with: "").trimmed as NSString
              default:
                  Log.astError("Unrecognized attribute format \(attribute.argument?.description ?? "")")
                  return
              }
          }

        self.init(name: attribute.attributeName.text.trimmed, arguments: arguments, description: attribute.description.trimmed)
    }

    static func from(_ attributes: AttributeListSyntax?, adding: [Attribute]? = []) -> [String: Attribute] {
        let array = attributes?
          .compactMap { $0.as(AttributeSyntax.self) }
          .map(Attribute.init) ?? []
        return Dictionary(uniqueKeysWithValues: (array + (adding ?? [])).map { ($0.name, $0) })
    }
}
