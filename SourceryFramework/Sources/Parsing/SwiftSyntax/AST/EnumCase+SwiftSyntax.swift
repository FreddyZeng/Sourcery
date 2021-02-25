import Foundation
import SwiftSyntax
import SourceryRuntime

extension EnumCase {

    convenience init(_ node: EnumCaseElementSyntax, parent: EnumCaseDeclSyntax, annotationsParser: AnnotationsParser) {
        var associatedValues: [AssociatedValue] = []
        if let paramList = node.associatedValue?.parameterList {
            let hasManyValues = paramList.count > 1
            associatedValues = paramList
              .enumerated()
              .map { (idx, param) in
                  let name = param.firstName?.text.trimmed.nilIfNotValidParameterName
                  let secondName = param.secondName?.text.trimmed
                  let type = param
                    .type?
                    .withoutLeadingTrivia().description.trimmed

                  let variadic = param.ellipsis != nil // TODO:
                  let defaultValue = param.defaultArgument?.value.description.trimmed
                  var externalName: String? = secondName
                  if externalName == nil, hasManyValues {
                      externalName = name ?? "\(idx)"
                  }

                  var collectedAnnotations = Annotations()
                  if let typeSyntax = param.type {
                      collectedAnnotations = annotationsParser.annotations(fromToken: typeSyntax)
                  }

                  return AssociatedValue(localName: name,
                                         externalName: externalName,
                                         typeName: type.map { TypeName($0) } ?? TypeName.unknown(description: parent.description.trimmed),
                                         type: nil,
                                         defaultValue: defaultValue,
                                         annotations: collectedAnnotations
                  )
              }
        }

        let rawValue: String? = {
            node.rawValue?.tokens.lazy
              .dropFirst()
              .compactMap { token in
                  switch token.tokenKind {
                  case .stringQuote, .singleQuote:
                      return nil
                  default:
                      return token.description.trimmed
                  }
              }
              .first
        }()

        let indirect = parent
          .modifiers?
          .contains { modifier in
              if modifier.description.trimmed == "indirect" {
                  return true
              }

              return false
          } ?? false

        self.init(
          name: node.identifier.text.trimmed,
          rawValue: rawValue,
          associatedValues: associatedValues,
          annotations: annotationsParser.annotations(from: node),
          indirect: indirect
        )
    }

    static func from(_ node: EnumCaseDeclSyntax, annotationsParser: AnnotationsParser) -> [EnumCase] {
        node.elements.compactMap {
            EnumCase($0, parent: node, annotationsParser: annotationsParser)
        }
    }
}