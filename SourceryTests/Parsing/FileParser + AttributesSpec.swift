import Quick
import Nimble
@testable import Sourcery
@testable import SourceryFramework
@testable import SourceryRuntime

class FileParserAttributesSpec: QuickSpec {
    override func spec() {

        describe("FileParser") {
            #warning("this needs update")
            guard let sut: FileParser = try? FileParser(contents: "") else { return fail() }

            func parse(_ code: String) -> [Type] {
                guard let parserResult = try? makeParser(for: code).parse() else { fail(); return [] }
                return Composer.uniqueTypesAndFunctions(parserResult).types
            }

            it("extracts type attributes") {
                expect(parse("class Foo { func some(param: @convention(swift) @escaping ()->()) {} }").first?.methods.first?.parameters.first?.typeAttributes).to(equal([
                    "escaping": Attribute(name: "escaping"),
                    "convention": Attribute(name: "convention", arguments: ["0": "swift" as NSString], description: "@convention(swift)")
                    ]))

                expect(parse("final class Foo { }").first?.attributes).to(equal([
                    "final": Attribute(name: "final", description: "final")
                    ]))

                expect(parse("@objc class Foo {}").first?.attributes).to(equal([
                    "objc": Attribute(name: "objc", arguments: [:], description: "@objc")
                    ]))

                expect(parse("@objc(Bar) class Foo {}").first?.attributes).to(equal([
                    "objc": Attribute(name: "objc", arguments: ["0": "Bar" as NSString], description: "@objc(Bar)")
                    ]))

                expect(parse("@objcMembers class Foo {}").first?.attributes).to(equal([
                    "objcMembers": Attribute(name: "objcMembers", arguments: [:], description: "@objcMembers")
                    ]))

                expect(parse("public class Foo {}").first?.attributes).to(equal([
                    "public": Attribute(name: "public", arguments: [:], description: "public")
                    ]))
            }

            context("given attribute with arguments") {
                it("extracts attribute arguments with values") {
                    expect(parse("""
                            @available(*, unavailable, renamed: \"NewFoo\")
                            protocol Foo {}
                            """
                            ).first?.attributes)
                        .to(equal([
                            "available": Attribute(name: "available", arguments: [
                                "0": "*" as NSString,
                                "1": "unavailable" as NSString,
                                "renamed": "NewFoo" as NSString
                                ], description: "@available(*, unavailable, renamed: \"NewFoo\")")
                            ]))

                    expect(parse("""
                            @available(iOS 10.0, macOS 10.12, *)
                            protocol Foo {}
                            """
                            ).first?.attributes)
                    .to(equal([
                        "available": Attribute(name: "available", arguments: [
                            "0": "iOS 10.0" as NSString,
                            "1": "macOS 10.12" as NSString,
                            "2": "*" as NSString
                            ], description: "@available(iOS 10.0, macOS 10.12, *)")
                        ]))
                }
            }

            it("extracts method attributes") {
                expect(parse("class Foo { @discardableResult\n@objc(some)\nfunc some() {} }").first?.methods.first?.attributes).to(equal([
                    "discardableResult": Attribute(name: "discardableResult"),
                    "objc": Attribute(name: "objc", arguments: ["0": "some" as NSString], description: "@objc(some)")
                    ]))

                expect(parse("class Foo { @nonobjc convenience required init() {} }").first?.initializers.first?.attributes).to(equal([
                    "nonobjc": Attribute(name: "nonobjc"),
                    "convenience": Attribute(name: "convenience", description: "convenience"),
                    "required": Attribute(name: "required", description: "required")
                    ]))

                expect(parse("struct Foo { mutating func some() {} }").first?.methods.first?.attributes).to(equal([
                    "mutating": Attribute(name: "mutating", description: "mutating")
                    ]))

                expect(parse("class Foo { final func some() {} }").first?.methods.first?.attributes).to(equal([
                    "final": Attribute(name: "final", description: "final")
                    ]))

                expect(parse("@objc protocol Foo { @objc optional func some() }").first?.methods.first?.attributes).to(equal([
                    "objc": Attribute(name: "objc", description: "@objc"),
                    "optional": Attribute(name: "optional", description: "optional")
                    ]))
            }

            it("extracts method parameter attributes") {
                expect(parse("class Foo { func some(param: @escaping ()->()) {} }").first?.methods.first?.parameters.first?.typeAttributes).to(equal([
                    "escaping": Attribute(name: "escaping")
                    ]))
            }

            it("extracts variable attributes") {
                expect(parse("class Foo { @NSCopying @objc(objcName) var name: NSString = \"\" }").first?.variables.first?.attributes).to(equal([
                    "NSCopying": Attribute(name: "NSCopying", description: "@NSCopying"),
                    "objc": Attribute(name: "objc", arguments: ["0": "objcName" as NSString], description: "@objc(objcName)")
                    ]))

                expect(parse("struct Foo { mutating var some: Int }").first?.variables.first?.attributes).to(equal([
                    "mutating": Attribute(name: "mutating", description: "mutating")
                    ]))

                expect(parse("class Foo { final var some: Int }").first?.variables.first?.attributes).to(equal([
                    "final": Attribute(name: "final", description: "final")
                    ]))

                expect(parse("class Foo { lazy var name: String = \"Hello\" }").first?.variables.first?.attributes).to(equal([
                    "lazy": Attribute(name: "lazy", description: "lazy")
                    ]))

                func assertSetterAccess(_ access: String, line: UInt = #line) {
                    expect(line: line, parse("public class Foo { \(access)(set) var some: Int }").first?.variables.first?.attributes).to(equal([
                        access: Attribute(name: access, arguments: ["0": "set" as NSString], description: "\(access)(set)")
                        ]))
                }

                assertSetterAccess("private")
                assertSetterAccess("fileprivate")
                assertSetterAccess("internal")
                assertSetterAccess("public")

                func assertGetterAccess(_ access: String, line: UInt = #line) {
                    expect(line: line, parse("public class Foo { \(access) var some: Int }").first?.variables.first?.attributes).to(equal([
                        access: Attribute(name: access, arguments: [:], description: "\(access)")
                        ]))
                }

                assertGetterAccess("private")
                assertGetterAccess("fileprivate")
                assertGetterAccess("internal")
                assertGetterAccess("public")

            }

            it("extracts type attributes") {
                expect(parse("@nonobjc class Foo {}").first?.attributes).to(equal([
                    "nonobjc": Attribute(name: "nonobjc")
                ]))
            }

        }
    }
}
