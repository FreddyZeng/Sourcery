import Foundation
import SwiftSyntax
import SourceryRuntime

extension SourceryMethod {
    convenience init(_ node: FunctionDeclSyntax, typeName: TypeName?) {
        self.init(
            node: node,
            identifier: node.identifier.text.trimmed,
            typeName: typeName,
            signature: Signature(node.signature),
            modifiers: node.modifiers,
            attributes: node.attributes,
            genericParameterClause: node.genericParameterClause,
            genericWhereClause: node.genericWhereClause
        )
    }

    convenience init(_ node: InitializerDeclSyntax, typeName: TypeName) {
        self.init(
            node: node,
            identifier: "init\(node.optionalMark?.text.trimmed ?? "")",
            typeName: typeName,
            signature: Signature(parameters: node.parameters.parameterList, output: nil, throwsOrRethrowsKeyword: node.throwsOrRethrowsKeyword?.description.trimmed),
            modifiers: node.modifiers,
            attributes: node.attributes,
            genericParameterClause: node.genericParameterClause,
            genericWhereClause: node.genericWhereClause
        )
    }

    convenience init(
        node: DeclSyntaxProtocol,
        identifier: String,
        typeName: TypeName?,
        signature: Signature,
        modifiers: ModifierListSyntax?,
        attributes: AttributeListSyntax?,
        genericParameterClause: GenericParameterClauseSyntax?,
        genericWhereClause: GenericWhereClauseSyntax?
    ) {
        let initializerNode = node as? InitializerDeclSyntax
        let attributesFromModifiers = modifiers?.map(Attribute.init) ?? []

        let isClass = attributesFromModifiers.contains(Attribute.classAttribute)
        let isStatic = initializerNode != nil ? true : attributesFromModifiers.contains(Attribute.staticAttribute)

        let access: AccessLevel = {
            return modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
        }()

        var returnTypeName = signature.output ?? (initializerNode != nil ? typeName?.name : nil) ?? "Void"
        let funcName = identifier.last == "?" ? String(identifier.dropLast()) : identifier
        var fullName = identifier
        if let generics = genericParameterClause?.genericParameterList {
            fullName = funcName + "<\(generics.description.trimmed)>"
        }

        if let genericWhereClause = genericWhereClause {
            // TODO: token walking to get rid of new lines etc in between
            returnTypeName = returnTypeName + " \(genericWhereClause.description.trimmed)"
        }

        let name = signature.definition(with: fullName)
        let selectorName = signature.selector(with: funcName)

        let attributes = attributes?
            .compactMap { $0.as(AttributeSyntax.self) }
            .map(Attribute.init) ?? []

        let attributesDictionary: [String: Attribute] = Dictionary(uniqueKeysWithValues: (attributesFromModifiers + attributes).map { ($0.name, $0) })
        
        self.init(
            name: name,
            selectorName: selectorName,
            parameters: signature.input,
            returnTypeName: TypeName(returnTypeName),
            throws: signature.throwsOrRethrowsKeyword == "throws",
            rethrows: signature.throwsOrRethrowsKeyword == "rethrows",
            accessLevel: access,
            isStatic: isStatic,
            isClass: isClass,
            isFailableInitializer: initializerNode?.optionalMark != nil,
            attributes: attributesDictionary,
            annotations: [:],
            definedInTypeName: typeName
        )
    }

}
