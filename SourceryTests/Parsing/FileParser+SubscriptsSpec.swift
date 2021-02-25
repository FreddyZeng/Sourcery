import Quick
import Nimble
import PathKit
import SourceKittenFramework
@testable import Sourcery
@testable import SourceryFramework
@testable import SourceryRuntime

class FileParserSubscriptsSpec: QuickSpec {

    override func spec() {
        describe("FileParser") {
            describe("parseSubscript") {
                func parse(_ code: String) -> [Type] {
                    guard let parserResult = try? makeParser(for: code).parse() else { fail(); return [] }
                    return Composer.uniqueTypesAndFunctions(parserResult).types
                }

                it("extracts subscripts properly") {
                    let subscripts = parse("""
                                           class Foo {
                                               final private subscript(_ index: Int, a: String) -> Int {
                                                   get { return 0 }
                                                   set { do {} }
                                               }
                                               public private(set) subscript(b b: Int) -> String {
                                                   get { return \"\"}
                                                   set { }
                                               }
                                           }
                                           """).first?.subscripts

                    expect(subscripts?.first).to(equal(
                        Subscript(
                            parameters: [
                                MethodParameter(argumentLabel: nil, name: "index", typeName: TypeName("Int")),
                                MethodParameter(argumentLabel: "a", name: "a", typeName: TypeName("String"))
                            ],
                            returnTypeName: TypeName("Int"),
                            accessLevel: (.private, .private),
                            attributes: [
                                "final": Attribute(name: "final", description: "final"),
                                "private": Attribute(name: "private", description: "private")
                            ],
                            annotations: [:],
                            definedInTypeName: TypeName("Foo")
                        )
                    ))

                    expect(subscripts?.last).to(equal(
                        Subscript(
                            parameters: [
                                MethodParameter(argumentLabel: "b", name: "b", typeName: TypeName("Int"))
                            ],
                            returnTypeName: TypeName("String"),
                            accessLevel: (.public, .private),
                            attributes: [
                                "public": Attribute(name: "public", description: "public"),
                                "private": Attribute(name: "private", arguments: ["0": "set" as NSString], description: "private(set)")
                            ],
                            annotations: [:],
                            definedInTypeName: TypeName("Foo")
                        )
                    ))
                }

                xit("extracts subscript annotations") {
                    let subscripts = parse("//sourcery: thisIsClass\nclass Foo {\n // sourcery: thisIsSubscript\nsubscript(\n\n/* sourcery: thisIsSubscriptParam */a: Int) -> Int { return 0 } }").first?.subscripts

                    let subscriptAnnotations = subscripts?.first?.annotations
                    expect(subscriptAnnotations).to(equal(["thisIsSubscript": NSNumber(value: true)]))

                    let paramAnnotations = subscripts?.first?.parameters.first?.annotations
                    expect(paramAnnotations).to(equal(["thisIsSubscriptParam": NSNumber(value: true)]))
                }
            }
        }
    }
}
