import Foundation
import SwiftSyntax
import SourceryRuntime

extension Subscript {
    convenience init(_ node: SubscriptDeclSyntax, parent: Type, annotationsParser: AnnotationsParser) {
        let modifiers = node.modifiers?.map(Modifier.init) ?? []
        let baseModifiers = modifiers.baseModifiers

        self.init(
          parameters: node.indices.parameterList.map(MethodParameter.init),
          returnTypeName: TypeName(node.result.returnType.description.trimmed),
          accessLevel: (baseModifiers.readAccess, baseModifiers.writeAccess),
          attributes: Attribute.from(node.attributes, adding: node
            .modifiers?
            .map(Modifier.init)
            .map(Attribute.init)),
          annotations: node.firstToken.map { annotationsParser.annotations(fromToken: $0) } ?? [:],
          definedInTypeName: TypeName(parent.name)
        )
    }
}