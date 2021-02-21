import SwiftSyntax
import SourceryRuntime

public struct Signature {
    /// The function inputs.
    public let input: [MethodParameter]

    /// The function output, if any.
    public let output: String?

    /// The `throws` or `rethrows` keyword, if any.
    public let throwsOrRethrowsKeyword: String?

    public init(_ node: FunctionSignatureSyntax) {
        self.init(parameters: node.input.parameterList,
             output: node.output?.returnType.description.trimmed,
             throwsOrRethrowsKeyword: node.throwsOrRethrowsKeyword?.description.trimmed
        )
    }

    public init(parameters: FunctionParameterListSyntax, output: String?, throwsOrRethrowsKeyword: String?) {
        input = parameters.map(MethodParameter.init)
        self.output = output
        self.throwsOrRethrowsKeyword = throwsOrRethrowsKeyword
    }

    public func definition(with name: String) -> String {
        let parameters = input
          .map { parameter in
              guard parameter.argumentLabel != parameter.name else {
                  return parameter.name + ": \(parameter.typeName.name)\(parameter.defaultValue.map { " = \($0)" } ?? "")"
              }

              let labels = [parameter.argumentLabel ?? "_", parameter.name.nilIfEmpty]
                .compactMap { $0 }
                .joined(separator: " ")

            return (labels.nilIfEmpty ?? "_") + ": \(parameter.typeName.name)\(parameter.defaultValue.map { " = \($0)" } ?? "")"
          }
          .joined(separator: ", ")

        let final = "\(name)(\(parameters))"
        // TODO: why not
//            if let keyword = throwsOrRethrowsKeyword {
//                final += " \(keyword)"
//            }
//            if let output = output {
//                final += " -> \(output)"
//            }

        return final
    }

    public func selector(with name: String) -> String {
        if input.isEmpty {
            return name
        }

        let parameters = input
          .map { "\($0.argumentLabel ?? "_"):" }
          .joined(separator: "")

        return "\(name)(\(parameters))"
    }
}
