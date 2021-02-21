import PathKit
import SourceryRuntime

public protocol FileParserType {

    var path: String? { get }

    var module: String? { get }

    var modifiedDate: Date? { get }

    var initialContents: String { get }

    /// Parses given contents.
    ///
    /// - Parameters:
    ///   - verbose: Whether it should log verbose
    ///   - contents: Contents to parse.
    ///   - path: Path to file.
    /// - Throws: parsing errors.
    init(contents: String, path: Path?, module: String?) throws

    /// Parses given file context.
    ///
    /// - Returns: All types we could find.
    func parse() throws -> FileParserResult
}

public func makeParser(for contents: String, path: Path? = nil, module: String? = nil) throws -> FileParserType {
//    try FileParser(contents: contents, path: path, module: module)
    try FileParserSyntax(contents: contents, path: path, module: module)
}
