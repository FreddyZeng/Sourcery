//
//  ParserFactory.swift
//  SourceryTests
//
//  Created by merowing on 2/21/21.
//  Copyright © 2021 Pixle. All rights reserved.
//

import Foundation
import SourceryRuntime
import SourceryFramework
import PathKit

func parser(contents: String, path: Path? = nil, module: String? = nil) throws -> FileParserType {
    try FileParser(contents: contents, path: path, module: module)
}
