// Everything an author can reach has something to say about itself.
//
// This library's whole premise is that somebody who knows MAUI should never have
// to guess: the names are MAUI's, so the only thing left to supply is what each
// one means and which MAUI property it stands for. That is a doc comment, and a
// doc comment is the one part of a library nothing else fails without - which is
// exactly why it needs a test rather than a habit.
//
// The C# side has the same rule enforced by the compiler: StateUI.Runtime sets
// GenerateDocumentationFile and promotes CS1591 and CS1573 to errors.
//
// A regex over source code is a poor way to know anything, and this is the
// second place it earns its keep, for the reason Fixtures.propertyKeys does: it
// is a TEST reading the library beside it, it runs nowhere near anything the
// library does, and a declaration it fails to recognize is one nobody is asked
// to document - never a false failure.

import Foundation
import XCTest
@testable import StateUI

final class DocumentationTests: XCTestCase {
    /// Names every public declaration with no `///` above it.
    ///
    /// Public, because that is the surface an application writes against. What is
    /// internal to the library is documented too - it is how the next session
    /// reads the differ - but only this can be insisted on without the rule
    /// turning into a demand for a comment on every `var copy = self`.
    func testEveryPublicApiIsDocumented() throws {
        var undocumented: [String] = []

        for source in try Fixtures.allSources() {
            let lines = source.text.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() where isPublicDeclaration(line) {
                if !isDocumented(lines, above: index) {
                    undocumented.append("\(source.path):\(index + 1)  \(line.trimmed)")
                }
            }
        }

        XCTAssertEqual(undocumented, [], """
            These are public and say nothing about themselves:

            \(undocumented.joined(separator: "\n"))

            Write a `///` above each - what it does, and the MAUI property it
            stands for, the way its neighbours do. That comment is what an author
            sees while typing, and it is the only place this library explains
            itself.
            """)
    }

    // MARK: - Reading a declaration

    /// Whether a line declares something an application can reach.
    ///
    /// Deliberately narrow: it looks for `public` on a line that starts a
    /// declaration, and nothing cleverer. A continuation line of a multi-line
    /// signature carries no keyword and is therefore not one of these, which is
    /// what keeps the check off the middle of an argument list.
    private func isPublicDeclaration(_ line: String) -> Bool {
        let text = line.trimmed

        guard text.hasPrefix("public ") || text.contains(" public ") else { return false }

        // THE MODIFIERS BETWEEN `public` AND THE KEYWORD ARE TAKEN OUT FIRST.
        // Matching `"public func "` as a substring meant `public static func`,
        // `public final class` and `nonisolated(nonsending) public func` were
        // not declarations at all as far as this test was concerned - 186 of
        // them, including every named colour, every `Draw` factory, every
        // `animateTo` and all three arranged-list initializers. They are all
        // documented today, which is the only reason this was a latent hole
        // rather than a live one.
        var head = text

        for modifier in ["static ", "final ", "class ", "convenience ", "indirect ",
                         "mutating ", "nonmutating ", "override ", "required ",
                         "nonisolated(nonsending) ", "nonisolated(unsafe) ",
                         "nonisolated ", "@discardableResult "] {
            head = head.replacingOccurrences(of: "public \(modifier)", with: "public ")
        }

        for keyword in ["func ", "var ", "let ", "init(", "init?(", "init<",
                        "subscript", "struct ", "enum ", "class ", "actor ",
                        "protocol ", "typealias ", "macro "] {
            if head.contains("public \(keyword)") || head.hasPrefix(keyword) {
                return true
            }
        }

        return false
    }

    /// EVERY CASE OF A PUBLIC ENUM, which the check above cannot see: a case
    /// carries no `public` of its own, it inherits the enum's.
    ///
    /// Every case gets a `///` of its own - `.aspectFit` against `.aspectFill`
    /// is exactly the choice a list of bare names cannot help with. A case on
    /// the same line as others (`case a, b`) is one declaration and needs one
    /// comment.
    func testEveryPublicEnumCaseIsDocumented() throws {
        var undocumented: [String] = []

        for source in try Fixtures.allSources() {
            let lines = source.text.components(separatedBy: "\n")
            var depth = 0
            var body: Int?

            for (index, line) in lines.enumerated() {
                let text = line.trimmed

                // AT THE ENUM'S OWN DEPTH AND NOWHERE ELSE. A `case` one level
                // deeper is a switch arm inside a computed property - the enum's
                // own `propValue` is full of them - and reading those as
                // declarations asks for a doc comment on every branch.
                if let inside = body, depth == inside, text.hasPrefix("case "),
                    !isDocumented(lines, above: index) {
                    undocumented.append("\(source.path):\(index + 1)  \(text)")
                }

                if body == nil, isPublicDeclaration(line), text.contains("enum ") {
                    body = depth + line.filter { $0 == "{" }.count
                }

                depth += line.filter { $0 == "{" }.count
                depth -= line.filter { $0 == "}" }.count

                if let inside = body, depth < inside { body = nil }
            }
        }

        XCTAssertEqual(undocumented, [], """
            These enum cases are public and say nothing about themselves:

            \(undocumented.joined(separator: "\n"))

            A bare list of names cannot tell an author which case they want. \
            Write a `///` above each, the way its neighbours have one.
            """)
    }

    /// EVERY MEMBER OF A `public extension`, which the first check cannot see
    /// either: a member inside one carries no `public` of its own, exactly as
    /// an enum case does not.
    ///
    /// Without this check that form is a way to publish a member the doc guard
    /// never asks about - the one shape that could get past a test whose whole
    /// subject is the public surface.
    ///
    /// THE TOKEN VOCABULARIES ARE EXEMPT, by name and on purpose: a `NodeType`,
    /// a `Prop` and an `Event` are names and nothing else, so a comment on one
    /// could only restate it, and what the name MEANS is on the modifier an
    /// author types. `Act` is NOT exempt - its name does not say which class
    /// the MAUI method sits on, so that is the one thing it has to say - which
    /// is also what keeps this test reading real declarations rather than
    /// passing over an empty list.
    func testEveryMemberOfAPublicExtensionIsDocumented() throws {
        // Names, not files: an exemption that covered Core/Tokens.swift whole
        // would cover whatever is added to it next.
        let exempt: Set<String> = ["NodeType", "Prop", "Event"]
        var undocumented: [String] = []

        for source in try Fixtures.allSources() {
            let lines = source.text.components(separatedBy: "\n")
            var depth = 0
            var body: Int?
            var extended = ""

            for (index, line) in lines.enumerated() {
                let text = line.trimmed

                if let inside = body, depth == inside, !exempt.contains(extended),
                    isMemberDeclaration(text), !isDocumented(lines, above: index) {
                    undocumented.append("\(source.path):\(index + 1)  \(text)")
                }

                if body == nil, text.hasPrefix("public extension ") {
                    extended = String(
                        text.dropFirst("public extension ".count)
                            .prefix { $0 != " " && $0 != ":" && $0 != "{" })
                    body = depth + line.filter { $0 == "{" }.count
                }

                depth += line.filter { $0 == "{" }.count
                depth -= line.filter { $0 == "}" }.count

                if let inside = body, depth < inside { body = nil }
            }
        }

        XCTAssertEqual(undocumented, [], """
            These sit in a `public extension` and say nothing about themselves:

            \(undocumented.joined(separator: "\n"))

            A member of a public extension is public without saying so. Write a \
            `///` above each - what it does, and the MAUI name it stands for.
            """)
    }

    /// Whether a line declares a member - inside an extension, where the
    /// `public` is the extension's rather than the member's.
    private func isMemberDeclaration(_ text: String) -> Bool {
        for keyword in ["static let ", "static var ", "static func ", "func ",
                        "var ", "let ", "init(", "init?(", "init<", "subscript",
                        "typealias "] where text.hasPrefix(keyword) {
            return true
        }

        return false
    }

    /// Whether the lines above a declaration document it.
    ///
    /// Attributes sit between a doc comment and what it describes -
    /// `@propertyWrapper`, `@_cdecl` - so they are stepped over. Anything else
    /// ends the search: a blank line, a `//` note, the brace above.
    private func isDocumented(_ lines: [String], above index: Int) -> Bool {
        var cursor = index - 1

        while cursor >= 0 {
            let text = lines[cursor].trimmed

            if text.hasPrefix("///") { return true }
            if text.hasPrefix("@") { cursor -= 1; continue }

            return false
        }

        return false
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
