import SwiftSyntax
import SourceryRuntime
import SourceryUtils

class SyntaxTreeCollector: SyntaxVisitor {
    var types = [Type]()
    var typealiases = [Typealias]()
    var methods = [SourceryMethod]()
    var imports = [Import]()
    private var visitingType: Type?

    let annotationsParser: AnnotationsParser
    let sourceLocationConverter: SourceLocationConverter
    let module: String?
    let file: String

    init(file: String, module: String?, annotations: AnnotationsParser, sourceLocationConverter: SourceLocationConverter) {
        self.annotationsParser = annotations
        self.file = file
        self.module = module
        self.sourceLocationConverter = sourceLocationConverter
    }

    private func startVisitingType(_ node: DeclSyntaxProtocol, _ builder: (_ parent: Type?) -> Type) {
        let type = builder(visitingType)

        if let open = node.tokens.first(where: { $0.tokenKind == .leftBrace }),
           let close = node.tokens
             .reversed()
             .first(where: { $0.tokenKind == .rightBrace }) {
            let startLocation = open.endLocation(converter: sourceLocationConverter)
            let endLocation = close.startLocation(converter: sourceLocationConverter)
            type.bodyBytesRange = SourceryRuntime.BytesRange(offset: Int64(startLocation.offset), length: Int64(endLocation.offset - startLocation.offset))
        } else {
            logError("Unable to find bodyRange for \(type.name)")
        }

        visitingType?.containedTypes.append(type)
        visitingType = type
        types.append(type)
    }

    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType(node) { parent in
            Struct(node, parent: parent, annotationsParser: annotationsParser)
        }
        return .visitChildren
    }

    public override func visitPost(_ node: StructDeclSyntax) {
        visitingType = visitingType?.parent
    }

    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType(node) { parent in
            Class(node, parent: parent, annotationsParser: annotationsParser)
        }
        return .visitChildren
    }

    public override func visitPost(_ node: ClassDeclSyntax) {
        visitingType = visitingType?.parent
    }

    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType(node) { parent in
            Enum(node, parent: parent, annotationsParser: annotationsParser)
        }

        return .visitChildren
    }

    public override func visitPost(_ node: EnumDeclSyntax) {
        visitingType = visitingType?.parent
    }

    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let variables = Variable.from(node, visitingType: visitingType, annotationParser: annotationsParser)
        if let visitingType = visitingType {
            visitingType.rawVariables.append(contentsOf: variables)
        }

        return .skipChildren
    }

    public override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let enumeration = visitingType as? Enum else {
            logError("EnumCase shouldn't appear outside of enum declaration \(node.description.trimmed)")
            return .skipChildren
        }

        enumeration.cases.append(contentsOf: EnumCase.from(node, annotationsParser: annotationsParser))
        return .skipChildren
    }

    public override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let visitingType = visitingType else {
            logError("deinit shouldn't appear outside of type declaration \(node.description.trimmed)")
            return .skipChildren
        }
        visitingType.rawMethods.append(
          SourceryMethod(node, typeName: TypeName(visitingType.name))
        )
        return .skipChildren
    }

    /// Called when visiting an `ExtensionDeclSyntax` node
    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType(node) { parent in
            let modifiers = node.modifiers?.map(Modifier.init) ?? []

            return Type(
              name: node.extendedType.description.trimmingCharacters(in: .whitespaces),
              parent: parent,
              accessLevel: modifiers.lazy.compactMap(AccessLevel.init).first ?? .internal,
              isExtension: true,
              variables: [],
              methods: [],
              subscripts: [],
              inheritedTypes: node.inheritanceClause?.inheritedTypeCollection.map { $0.typeName.description.trimmed } ?? [],
              containedTypes: [],
              typealiases: [],
              attributes: Attribute.from(node.attributes, adding: modifiers.map(Attribute.init)),
              annotations: annotationsParser.annotations(fromToken: node.extensionKeyword), 
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

    public override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.append(Import(path: node.path.description.trimmed, kind: node.importKind?.text.trimmed))
        return .skipChildren
    }

    public override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let visitingType = visitingType else {
            logError("init shouldn't appear outside of type declaration \(node.description.trimmed)")
            return .skipChildren
        }
        let method = SourceryMethod(node, typeName: TypeName(visitingType.name))
        visitingType.rawMethods.append(method)
        return .skipChildren
    }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        startVisitingType(node) { parent in
            SourceryProtocol(node, parent: parent, annotationsParser: annotationsParser)
        }
        return .visitChildren
    }

    public override func visitPost(_ node: ProtocolDeclSyntax) {
        visitingType = visitingType?.parent
    }

    public override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let visitingType = visitingType else {
            logError("subscript shouldn't appear outside of type declaration \(node.description.trimmed)")
            return .skipChildren
        }

        visitingType.rawSubscripts.append(
          Subscript(node, parent: visitingType, annotationsParser: annotationsParser)
        )

        return .skipChildren
    }

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
          typeName: typeName.nilIfEmpty.map { TypeName($0) } ?? TypeName.unknown(description: node.description.trimmed),
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


    public override func visit(_ node: OperatorDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }

    public override func visit(_ node: PrecedenceGroupDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }

    public override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        return .visitChildren
    }

    private func processPossibleProtocolComposition(for typeName: String, localName: String) -> Type? {
        if let composedTypeNames = FileParserSyntax.extractComposedTypeNames(from: typeName, trimmingCharacterSet: .whitespaces), composedTypeNames.count > 1 {
            let inheritedTypes = composedTypeNames.map { $0.name }
            let composition = ProtocolComposition(name: localName, parent: visitingType, inheritedTypes: inheritedTypes, composedTypeNames: composedTypeNames)
            return composition
        }

        return nil
    }

    private func logError(_ message: Any) {
        let prefix = file + ": "
        if let module = module {
            Log.astError("\(prefix) \(message) in module \(module)")
        } else {
            Log.astError("\(prefix) \(message)")
        }
    }
}
