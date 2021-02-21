import SwiftSyntax
import SourceryRuntime

extension MethodParameter {
    convenience init(_ node: FunctionParameterSyntax) {
        let firstName = node.firstName?.text.trimmed.nilIfNotValidParameterName
        let nodeName = node.type?.description.trimmed

        var isInOut = false // TODO: can I use AttributedTypeSyntax here?
        node.type?.tokens.forEach { token in
            switch token.tokenKind {
            case .inoutKeyword:
                isInOut = true
            default:
                break
            }
        }

        var attributes = [String: Attribute]()
        if let node = node.type?.as(AttributedTypeSyntax.self) {
            attributes = Attribute.from(node.attributes)
            // TODO: if I use baseType.description.trimmed I can simplify the TypeName so it avoids doing that
        }

        let typeName = nodeName.map { TypeName($0, attributes: attributes) } ?? TypeName("Unknown", attributes: attributes)

        self.init(
            argumentLabel: firstName,
            name: node.secondName?.text.trimmed ?? firstName ?? "",
            typeName: typeName,
            type: nil,
            defaultValue: node.defaultArgument?.value.description.trimmed,
            annotations: [:],
            isInout: isInOut
        )
    }
}
