import Foundation
import SourceryRuntime
import SwiftSyntax

extension SourceryProtocol {
    convenience init(_ node: ProtocolDeclSyntax, parent: Type?, annotationsParser: AnnotationsParser) {
        let modifiers = node.modifiers?.map(Modifier.init) ?? []

        self.init(
          name: node.identifier.text.trimmingCharacters(in: .whitespaces),
          parent: parent,
          accessLevel: modifiers.lazy.compactMap(AccessLevel.init).first ?? .internal,
          isExtension: false,
          variables: [],
          methods: [],
          subscripts: [],
          inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
          containedTypes: [],
          typealiases: [],
          attributes: Attribute.from(node.attributes, adding: modifiers.map(Attribute.init)),
          annotations: annotationsParser.annotations(from: node),
          isGeneric: false // TODO: add associated type?
        )
    }
}