//
//  FileParserSyntax.swift
//  SourceryFramework
//
//  Created by merowing on 2/21/21.
//  Copyright © 2021 Pixle. All rights reserved.
//

import Foundation
import SwiftSyntax
import PathKit
import SourceryRuntime
import SourceryUtils

extension TriviaPiece {
    public var comment: String? {
        switch self {
        case .spaces,
             .tabs,
             .verticalTabs,
             .formfeeds,
             .newlines,
             .carriageReturns,
             .carriageReturnLineFeeds,
             .garbageText:
            return nil
        case .lineComment(let comment),
             .blockComment(let comment),
             .docLineComment(let comment),
             .docBlockComment(let comment):
            return comment
        }
    }
}


protocol IdentifierSyntax: SyntaxProtocol {
    var identifier: TokenSyntax { get }
}

extension ClassDeclSyntax: IdentifierSyntax {}
extension StructDeclSyntax: IdentifierSyntax {}
extension EnumDeclSyntax: IdentifierSyntax {}
extension ProtocolDeclSyntax: IdentifierSyntax {}
extension FunctionDeclSyntax: IdentifierSyntax {}
extension TypealiasDeclSyntax: IdentifierSyntax {}
extension OperatorDeclSyntax: IdentifierSyntax {}
extension EnumCaseElementSyntax: IdentifierSyntax {}

private class TreeCollector: SyntaxVisitor {
    var types = [Type]()
    var typealiases = [Typealias]()
    var methods = [SourceryMethod]()
    var imports = [String]()
    private var visitingType: Type?

    let annotations: AnnotationsParser
    let sourceLocationConverter: SourceLocationConverter

    init(annotations: AnnotationsParser, sourceLocationConverter: SourceLocationConverter) {
        self.annotations = annotations
        self.sourceLocationConverter = sourceLocationConverter
    }

    private func startVisitingType(_ builder: (_ parent: Type?) -> Type) {
        let type = builder(visitingType)
        visitingType?.containedTypes.append(type)
        visitingType = type
        types.append(type)
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType { parent in
            let access: AccessLevel = {
                return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
            }()

            return Struct(
                name: node.identifier.text.trimmed,
                parent: parent,
                accessLevel: access,
                isExtension: false,
                variables: [],
                methods: [],
                subscripts: [],
                inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
                containedTypes: [],
                typealiases: [],
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: annotations(from: node),
                isGeneric: node.genericParameterClause?.genericParameterList.isEmpty == false
            )
        }
        return .visitChildren
    }

    public override func visitPost(_ node: StructDeclSyntax) {
        visitingType = visitingType?.parent
    }

    /// Called when visiting a `ClassDeclSyntax` node
    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType { parent in
            let access: AccessLevel = {
                return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
            }()

            return Class(
                name: node.identifier.text.trimmingCharacters(in: .whitespaces),
                parent: parent,
                accessLevel: access,
                isExtension: false,
                variables: [],
                methods: [],
                subscripts: [],
                inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
                containedTypes: [],
                typealiases: [],
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: annotations(from: node),
                isGeneric: node.genericParameterClause?.genericParameterList.isEmpty == false
            )
        }
        return .visitChildren
    }

    public override func visitPost(_ node: ClassDeclSyntax) {
        visitingType = visitingType?.parent
    }

    /// Called when visiting an `EnumDeclSyntax` node
    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType { parent in
            let access: AccessLevel = {
                return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
            }()

            //let rawTypeName: String? = node.inheritanceClause?.inheritedTypeCollection.first?.typeName.description.trimmed ?? nil
            return Enum(
                name: node.identifier.text.trimmingCharacters(in: .whitespaces),
                parent: parent,
                accessLevel: access,
                isExtension: false,
                inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
                rawTypeName: nil,
                cases: [],
                variables: [],
                methods: [],
                containedTypes: [],
                typealiases: [],
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: annotations(from: node),
                isGeneric: node.genericParameters?.genericParameterList.isEmpty == false
            )
        }

        return .visitChildren
    }

    public override func visitPost(_ node: EnumDeclSyntax) {
        visitingType = visitingType?.parent
    }

    /// Called when visiting a `VariableDeclSyntax` node
    public override func visit(_ parent: VariableDeclSyntax) -> SyntaxVisitorContinueKind {

        var readAccess: AccessLevel = .none
        var writeAccess: AccessLevel = .none
        var isStatic: Bool = false

        let attributesFromModifiers = parent.modifiers?.map(Attribute.init)

        // TODO: cleanup this
        parent.modifiers?.forEach { modifier in
            if modifier.name.tokenKind == .staticKeyword || modifier.name.tokenKind == .classKeyword {
                isStatic = true
            }

            guard let accessLevel = AccessLevel(modifier) else {
                return
            }

            if let detail = modifier.detail, detail.text.trimmed == "set" {
                writeAccess = accessLevel
            } else {
                readAccess = accessLevel
                if writeAccess == .none {
                    writeAccess = accessLevel
                }
            }
        }

        if readAccess == .none {
            readAccess = .internal
        }
        if writeAccess == .none {
            writeAccess = readAccess
        }

        let variables = parent.bindings.map { (node: PatternBindingSyntax) -> Variable in
            var hadGetter = false
            var hadSetter = false

            if let block = node.accessor?.as(AccessorBlockSyntax.self) {
                enum Kind: String {
                    case get
                    case set
                }

                let computeAccessors = Set(block.accessors.compactMap { accessor in
                    Kind(rawValue: accessor.accessorKind.text.trimmed)
                })

                if !computeAccessors.isEmpty {
                    if !computeAccessors.contains(Kind.set) {
                        writeAccess = .none
                    } else {
                        hadSetter = true
                    }

                    if !computeAccessors.contains(Kind.get) {
                    } else {
                        hadGetter = true
                    }
                }
            } else if node.accessor != nil {
                hadGetter = true
            }

            let isComputed = node.initializer == nil && hadGetter && !(visitingType is SourceryProtocol)
            let isWritable = parent.letOrVarKeyword.tokens.contains { $0.tokenKind == .varKeyword  } && (!isComputed || hadSetter)

            let typeName = node.typeAnnotation.map { TypeName($0.type.description.trimmed) } ??
                node.initializer.flatMap { inferType($0.value.description.trimmed) }

            return Variable(
                name: node.pattern.description.trimmed,
                typeName: typeName ?? TypeName("Unknown"),
                type: nil,
                accessLevel: (read: readAccess, write: isWritable ? writeAccess : .none),
                isComputed: isComputed,
                isStatic: isStatic,
                defaultValue: node.initializer?.value.description.trimmingCharacters(in: .whitespacesAndNewlines),
                attributes: Attribute.from(parent.attributes, adding: attributesFromModifiers),
                annotations: annotations(fromToken: parent.letOrVarKeyword),
                definedInTypeName: visitingType.map { TypeName($0.name) }
            )
        }

        if let visitingType = visitingType {
            visitingType.rawVariables.append(contentsOf: variables)
        }

        return .skipChildren
    }

    /// Called when visiting an `EnumCaseDeclSyntax` node
    public override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let enumeration = visitingType as? Enum else {
            assertionFailure("EnumCase shouldn't appear outside of enum declaration")
            return .skipChildren
        }

        let cases: [EnumCase] = node.elements.compactMap { caseNode in
            var associatedValues: [AssociatedValue] = []
            if let paramList = caseNode.associatedValue?.parameterList {
                let hasManyValues = paramList.count > 1
                associatedValues = paramList.enumerated().map { (idx, param) in
                    var name = param.firstName?.text.trimmed.nilIfNotValidParameterName
                    let secondName = param.secondName?.text.trimmed
                    let type = param.type?.withoutLeadingTrivia().description.trimmed

                    let variadic = param.ellipsis != nil // TODO:
                    let defaultValue = param.defaultArgument?.value.description.trimmed
                    var externalName: String? = secondName
                    if externalName == nil, hasManyValues {
                        externalName = name ?? "\(idx)"
                    }

                    let collectedAnnotations = param.type.map { annotations(fromToken: $0) }
                    return AssociatedValue(localName: name,
                                           externalName: externalName,
                                           typeName: type.map { TypeName($0) } ?? TypeName("Unknown"),
                                           type: nil,
                                           defaultValue: defaultValue,
                                           annotations: collectedAnnotations ?? [:]
                    )
                }
            }

            let rawValue: String? = {
                caseNode.rawValue?.tokens.lazy
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

            let indirect = node.modifiers?.contains { modifier in
                if modifier.description.trimmed == "indirect" {
                    return true
                }

                return false
            } ?? false

            return EnumCase(
                name: caseNode.identifier.text.trimmed,
                rawValue: rawValue,
                associatedValues: associatedValues,
                annotations: annotations(from: caseNode),
                indirect: indirect
            )
        }

        enumeration.cases.append(contentsOf: cases)

        return .skipChildren
    }

    public override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        // TODO: method code reuse!
        // TODO: generic constraints

        let access: AccessLevel = {
            return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
        }()

        let method = SourceryMethod(
            name: "deinit",
            selectorName: "deinit",
            parameters: [],
            returnTypeName: TypeName("Void"),
            throws: false,
            rethrows: false,
            accessLevel: access,
            isStatic: false,
            isClass: false,
            isFailableInitializer: false,
            attributes: [:],
            annotations: [:], // node.deinitKeyword
            definedInTypeName: visitingType.map { TypeName($0.name) }
        )

        if let visitingType = visitingType {
            visitingType.rawMethods.append(method)
        } else {
            methods.append(method)
        }

        return .skipChildren
    }

    /// Called when visiting an `ExtensionDeclSyntax` node
    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType { parent in
            let access: AccessLevel = {
                return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
            }()

            return Type(
                name: node.extendedType.description.trimmingCharacters(in: .whitespaces),
                parent: parent,
                accessLevel: access,
                isExtension: true,
                variables: [],
                methods: [],
                subscripts: [],
                inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
                containedTypes: [],
                typealiases: [],
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: [:], // TODO:
                isGeneric: false
            )
        }
        return .visitChildren
    }

    public override func visitPost(_ node: ExtensionDeclSyntax) {
        visitingType = visitingType?.parent
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let method = Method(node, typeName: visitingType.map { TypeName($0.name) })
        if let visitingType = visitingType {
            visitingType.rawMethods.append(method)
        } else {
            methods.append(method)
        }

        return .skipChildren
    }

    /// Called when visiting an `IfConfigDeclSyntax` node
    public override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        //        conditionalCompilationBlocks.append(ConditionalCompilationBlock(node))
        return .visitChildren
    }

    /// Called when visiting an `ImportDeclSyntax` node
    public override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.append(node.path.description.trimmed)
        return .skipChildren
    }

    /// Called when visiting an `InitializerDeclSyntax` node
    public override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let visitingType = visitingType else {
            assertionFailure("Shouldn't happen")
            return .skipChildren
        }
        let method = SourceryMethod(node, typeName: TypeName(visitingType.name))
        visitingType.rawMethods.append(method)
        return .skipChildren
    }

    /// Called when visiting an `OperatorDeclSyntax` node
    public override func visit(_ node: OperatorDeclSyntax) -> SyntaxVisitorContinueKind {
        //        operators.append(Operator(node))
        return .skipChildren
    }

    /// Called when visiting a `PrecedenceGroupDeclSyntax` node
    public override func visit(_ node: PrecedenceGroupDeclSyntax) -> SyntaxVisitorContinueKind {
        //        precedenceGroups.append(PrecedenceGroup(node))
        return .skipChildren
    }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType { parent in
            let access: AccessLevel = {
                return node.modifiers?.lazy.compactMap(AccessLevel.init).first ?? .internal
            }()

            return Protocol(
                name: node.identifier.text.trimmingCharacters(in: .whitespaces),
                parent: parent,
                accessLevel: access,
                isExtension: false,
                variables: [],
                methods: [],
                subscripts: [],
                inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
                containedTypes: [],
                typealiases: [],
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: annotations(from: node),
                isGeneric: false // TODO: add associated type?
            )
        }
        return .visitChildren
    }

    public override func visitPost(_ node: ProtocolDeclSyntax) {
        visitingType = visitingType?.parent
    }


    /// Called when visiting a `SubscriptDeclSyntax` node
    public override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let visitingType = visitingType else {
            assertionFailure("Shouldn't happen")
            return .skipChildren
        }


        var readAccess: AccessLevel = .none
        var writeAccess: AccessLevel = .none

        // TODO: cleanup this
        node.modifiers?.forEach { modifier in
            guard let accessLevel = AccessLevel(modifier) else {
                return
            }

            if let detail = modifier.detail, detail.text.trimmed == "set" {
                writeAccess = accessLevel
            } else {
                readAccess = accessLevel
                if writeAccess == .none {
                    writeAccess = accessLevel
                }
            }
        }

        if readAccess == .none {
            readAccess = .internal
        }
        if writeAccess == .none {
            writeAccess = readAccess
        }

        visitingType.rawSubscripts.append(
            Subscript(
                parameters: node.indices.parameterList.map(MethodParameter.init),
                returnTypeName: TypeName(node.result.returnType.description.trimmed),
                accessLevel: (readAccess, writeAccess),
                attributes: Attribute.from(node.attributes, adding: node.modifiers?.map(Attribute.init)),
                annotations: [:], // TODO:
                definedInTypeName: TypeName(visitingType.name)
            )
        )

        return .skipChildren
    }

    /// Called when visiting a `TypealiasDeclSyntax` node
    public override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        let localName = node.identifier.text.trimmed
        let typeName = node.initializer?.value.description.trimmed ?? ""

        if let composition = processPossibleProtocolComposition(for: typeName, localName: localName) {
            if let visitingType = visitingType {
                visitingType.containedTypes.append(composition)
            } else {
                types.append(composition)
            }
            
            return .skipChildren
        }

        let alias = Typealias(
            aliasName: localName,
            typeName: TypeName(typeName),
            parent: visitingType
        )

        // TODO: add generic requirements
        if let visitingType = visitingType {
            visitingType.typealiases[localName] = alias
        } else {
            // global typealias
            typealiases.append(alias)
        }
        return .skipChildren
    }

    /// Called when visiting an `AssociatedtypeDeclSyntax` node
    public override func visit(_ node: AssociatedtypeDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let sourceryProtocol = visitingType as? SourceryProtocol else {
            return .skipChildren
        }

        let name = node.identifier.text.trimmed
        var typeName: TypeName?
        var type: Type?
        if let possibleTypeName = node.inheritanceClause?.inheritedTypeCollection.description.trimmed {
            type = processPossibleProtocolComposition(for: possibleTypeName, localName: "")
            typeName = TypeName(possibleTypeName)
        }

        sourceryProtocol.associatedTypes[name] = AssociatedType(name: name, typeName: typeName, type: type)
        return .skipChildren
    }

    private func inferType(_ code: String) -> TypeName? {
        var code = code
        if code.hasSuffix("{") {
            code = String(code.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        let infered = FileParserSyntax.inferType(from: code)
        return infered.map { TypeName($0) } ?? nil
    }

    private func processPossibleProtocolComposition(for typeName: String, localName: String) -> Type? {
        if let composedTypeNames = FileParserSyntax.extractComposedTypeNames(from: typeName, trimmingCharacterSet: .whitespaces), composedTypeNames.count > 1 {
            let inheritedTypes = composedTypeNames.map { $0.name }
            let composition = ProtocolComposition(name: localName, parent: visitingType, inheritedTypes: inheritedTypes, composedTypeNames: composedTypeNames)
            return composition
        }

        return nil
    }


    private func findLocation(syntax: SyntaxProtocol) -> SourceLocation {
        return sourceLocationConverter.location(for: syntax.positionAfterSkippingLeadingTrivia)
    }

    private func annotations(from node: IdentifierSyntax) -> Annotations {
        annotations.from(
            location: findLocation(syntax: node.identifier),
            precedingComments: node.leadingTrivia?.compactMap({ $0.comment }) ?? []
        )
    }

    private func annotations(fromToken token: SyntaxProtocol) -> Annotations {
        annotations.from(
            location: findLocation(syntax: token),
            precedingComments: token.leadingTrivia?.compactMap({ $0.comment }) ?? []
        )
    }
}

public final class FileParserSyntax: SyntaxVisitor, FileParserType {

    public let path: String?

    public let module: String?

    public let modifiedDate: Date?

    public let initialContents: String
 
    fileprivate var annotations: AnnotationsParser!
    fileprivate var inlineRanges: [String: NSRange]!
    fileprivate var inlineIndentations: [String: String]!

    /// Parses given contents.
    ///
    /// - Parameters:
    ///   - verbose: Whether it should log verbose
    ///   - contents: Contents to parse.
    ///   - path: Path to file.
    /// - Throws: parsing errors.
    public init(contents: String, path: Path? = nil, module: String? = nil) throws {
        self.path = path?.string
        self.modifiedDate = path.flatMap({ (try? FileManager.default.attributesOfItem(atPath: $0.string)[.modificationDate]) as? Date })
        self.module = module
        self.initialContents = contents
    }

    /// Parses given file context.
    ///
    /// - Returns: All types we could find.
    public func parse() throws -> FileParserResult {
        // Inline handling
        let inline = TemplateAnnotationsParser.parseAnnotations("inline", contents: initialContents)
        let contents = inline.contents
        inlineRanges = inline.annotatedRanges.mapValues { $0[0].range }
        inlineIndentations = inline.annotatedRanges.mapValues { $0[0].indentation }
        annotations = AnnotationsParser(contents: contents)

        // Syntax walking
        let tree = try SyntaxParser.parse(source: contents)
        let sourceLocationConverter = SourceLocationConverter(file: path ?? "in-memory", tree: tree)
        let collector = TreeCollector(annotations: annotations, sourceLocationConverter: sourceLocationConverter)
        collector.walk(tree)

        collector.types.forEach { $0.imports = collector.imports }

        return FileParserResult(
          path: path,
          module: module,
          types: collector.types,
          functions: collector.methods,
          typealiases: collector.typealiases,
          inlineRanges: inlineRanges,
          inlineIndentations: inlineIndentations,
          modifiedDate: modifiedDate ?? Date(),
          sourceryVersion: SourceryVersion.current.value
        )
    }

}
