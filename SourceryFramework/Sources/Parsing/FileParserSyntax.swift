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

public final class FileParserSyntax: FileParserType {

    public let path: String?

    public let module: String?

    public let modifiedDate: Date?

    public let initialContents: String

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

    public func parseContentsIfNeeded() -> String { "" }

    /// Parses given file context.
    ///
    /// - Returns: All types we could find.
    public func parse() throws -> FileParserResult { .init(path: nil, module: nil, types: [], functions: []) }
}
