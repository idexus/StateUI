// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The shape of a composed view.
//
// A `ContentView` is what a piece of interface IS in this library, and the
// question every one of them answers is: how does a caller configure it? The
// library answers with MODIFIERS - `CollectionView(rows).itemSize(44).selection($x)`
// - which is the same answer every control gives, because the rule is written
// down for controls: only the value that gives a control its purpose goes in
// the initializer.
//
// The gallery is held to the same answer as the library, because the app
// exists to show the library how to be written: a composed view configured
// through memberwise initializer arguments - `Card(title:summary:icon:action:)`
// - would teach a second answer to that one question, in the very place an
// author copies from.
//
// The line between the two is MECHANICAL, which is what makes it checkable: a
// stored property with a DEFAULT is one a caller may leave out, which is the
// definition of configuration; one without a default is the view's purpose and
// the initializer is where it belongs. So configuration is `private` with a
// modifier over it, and the memberwise initializer is not a configuration door.
//
// The same for an explicit initializer's parameters: a defaulted parameter is
// the same door with the same knob on it, so an optional argument is a second
// initializer delegating to the first - the pair `FrameReader` and `CollectionView`
// both carry.

import Foundation
import XCTest

@testable import StateUI

final class CompositionTests: XCTestCase {
    /// What every composed view is checked for: nothing a caller may leave out
    /// is reachable through its initializer.
    ///
    /// Both halves of the repository, because the rule is one rule - the
    /// library's own composed views and every view an application declares.
    /// The property named `node` is exempt: it is `VisualElement`'s
    /// requirement, not a caller's knob.
    func testAComposedViewTakesNoConfigurationInItsInitializer() throws {
        var checked = 0
        var offenders: [String] = []

        for view in try composedViews() {
            checked += 1

            for property in view.storedPropertiesWithDefaults where property.name != "node" {
                offenders.append(
                    "\(view.file): \(view.name).\(property.name) is a defaulted stored property "
                        + "that is not private, so it is a memberwise initializer argument. "
                        + "Make it private and give it a modifier returning Self.")
            }

            for parameter in view.defaultedInitParameters {
                offenders.append(
                    "\(view.file): \(view.name).init has a defaulted parameter '\(parameter)'. "
                        + "A value a caller may leave out is a modifier, or a second "
                        + "initializer delegating to this one - see FrameReader.")
            }
        }

        XCTAssertGreaterThan(
            checked, 40,
            "the scanner found almost no composed views - it has stopped reading the sources.")

        XCTAssertEqual(
            offenders, [],
            "a composed view is configured by modifiers, never by initializer arguments:\n"
                + offenders.joined(separator: "\n"))
    }

    /// And the other half of the same rule: a view that takes configuration
    /// has somewhere to put it, so every gallery view with private
    /// configuration offers a modifier for it.
    ///
    /// Weaker than it sounds and deliberately so - it counts modifiers rather
    /// than matching them to properties, because a modifier may set two fields
    /// at once. What it catches is the shape that would otherwise pass the test
    /// above by hiding a knob nobody can turn.
    func testAViewWithPrivateConfigurationOffersModifiersForIt() throws {
        var offenders: [String] = []

        for view in try composedViews() where view.file.hasPrefix("apps/") {
            let configuration = view.privateConfiguration.filter { $0 != "node" }

            if !configuration.isEmpty, view.modifierNames.isEmpty {
                offenders.append(
                    "\(view.file): \(view.name) keeps \(configuration.joined(separator: ", ")) "
                        + "and offers no modifier returning Self, so nothing can set it.")
            }
        }

        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: - Reading the sources

    /// One type declaration, as much of it as this test needs.
    private struct ComposedView {
        /// What it is called.
        let name: String

        /// Where it is, relative to the repository - so a failure names a path
        /// that can be opened.
        let file: String

        /// The declaration's own lines, nested types and function bodies left
        /// out: only what is written directly in the type.
        let lines: [String]

        /// The whole body, for reading an initializer's parameter list out of.
        let body: String

        /// Stored properties with a default that a caller can therefore pass.
        var storedPropertiesWithDefaults: [(name: String, line: String)] {
            lines.compactMap { line in
                guard let name = storedPropertyWithDefault(in: line),
                    !isPrivate(line)
                else { return nil }

                return (name, line)
            }
        }

        /// The private ones - configuration that a modifier must reach.
        ///
        /// A property wrapper is not configuration: `@State` is what the view
        /// REMEMBERS, `@Environment` what it was handed, and neither is a
        /// caller's to set. Neither is a `let` - a constant the view is built
        /// out of, which a modifier could not change if it wanted to. What is
        /// left is a plain stored `var` with a default, which is exactly what a
        /// modifier exists to change.
        var privateConfiguration: [String] {
            lines.compactMap { line in
                let text = line.trimmingCharacters(in: .whitespaces)

                guard !text.hasPrefix("@"),
                    text.contains("var "),
                    let name = storedPropertyWithDefault(in: line),
                    isPrivate(line)
                else { return nil }

                return name
            }
        }

        /// Every parameter of an explicit initializer that carries a default.
        var defaultedInitParameters: [String] {
            var found: [String] = []

            for list in parameterLists(of: "init", in: body) {
                for parameter in parameters(in: list) where parameter.contains("=") {
                    let named = parameter.components(separatedBy: ":")[0]
                    found.append(named.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            return found
        }

        /// The functions that give back another of this view - what a modifier
        /// is here.
        var modifierNames: [String] {
            lines.compactMap { line in
                guard line.contains("-> Self"),
                    let name = line.range(of: #"func\s+([a-zA-Z_][a-zA-Z0-9_]*)"#, options: .regularExpression)
                else { return nil }

                return String(line[name].split(separator: " ").last ?? "")
            }
        }
    }

    /// Every composed view in the repository: the library's `ContentView`s and
    /// every view an application declares.
    ///
    /// An application's views are taken whatever they conform to - `MenuRow` is
    /// an `Element` rather than a `ContentView`, being a row with no state, and
    /// the rule is the same for it. The LIBRARY's plain `View`s are its control
    /// wrappers, which the control recipe and the fixtures already hold to
    /// their own shape.
    private func composedViews() throws -> [ComposedView] {
        let repository = Fixtures.repository
        var found: [ComposedView] = []

        let roots = [
            ("src/StateUI/Sources", ["ContentView"]),
            ("apps", ["ContentView", "Element", "View"]),
        ]

        // Protocols that REFINE ContentView carry the rule with them -
        // `SampleContent` is what every gallery sample is written against.
        var composed = Set(["ContentView"])
        var files: [(path: String, source: String)] = []

        for (root, _) in roots {
            for file in swiftFiles(under: repository.appendingPathComponent(root)) {
                let path = file.path.replacingOccurrences(of: repository.path + "/", with: "")
                files.append((path, sourceWithoutLiterals(try String(contentsOf: file, encoding: .utf8))))
            }
        }

        var grew = true
        while grew {
            grew = false

            for file in files {
                for declaration in declarations(in: file.source, kinds: ["protocol"]) {
                    if !composed.contains(declaration.name),
                        !composed.isDisjoint(with: declaration.conformances)
                    {
                        composed.insert(declaration.name)
                        grew = true
                    }
                }
            }
        }

        // A type may be made a view by an EXTENSION rather than by its own
        // declaration - `extension Card: ContentView {}` - and one written that
        // way would otherwise never be looked at, so its name is collected here
        // and matched below whatever the declaration says.
        //
        // PER ROOT, using that root's own set: the library counts `ContentView`
        // alone, and taking `Element` there too made `Node` - which conforms by
        // extension and is the wire's data structure rather than a view - a
        // composed view with four defaulted initializer parameters.
        var extended: [String: Set<String>] = [:]

        for (root, kinds) in roots {
            let wanted = Set(kinds).union(composed)
            var names: Set<String> = []

            for file in files where file.path.hasPrefix(root + "/") {
                for declaration in declarations(in: file.source, kinds: ["extension"])
                where !wanted.isDisjoint(with: declaration.conformances) {
                    names.insert(declaration.name)
                }
            }

            extended[root] = names
        }

        for file in files {
            guard let root = roots.first(where: { file.path.hasPrefix($0.0 + "/") }) else { continue }

            let wanted = Set(root.1).union(composed)
            let extended = extended[root.0] ?? []

            for declaration in declarations(in: file.source, kinds: ["struct", "class", "final class"])
            where !wanted.isDisjoint(with: declaration.conformances)
                || extended.contains(declaration.name) {
                found.append(
                    ComposedView(
                        name: declaration.name,
                        file: file.path,
                        lines: ownLines(of: declaration.body),
                        body: declaration.body))
            }
        }

        return found
    }

    /// Every `.swift` file under a directory, `.build` scratch left out - a
    /// checkout of swift-syntax lives under an app's `.build` and is not this
    /// repository's code.
    private func swiftFiles(under directory: URL) -> [URL] {
        guard let walk = FileManager.default.enumerator(atPath: directory.path) else { return [] }

        var found: [URL] = []

        for case let relative as String in walk {
            let normalized = relative.replacingOccurrences(of: "\\", with: "/")

            guard normalized.hasSuffix(".swift"),
                !normalized.contains(".build/"),
                !normalized.hasSuffix("Package.swift")
            else { continue }

            found.append(directory.appendingPathComponent(relative))
        }

        return found
    }

    /// The source with every multi-line string literal taken out.
    ///
    /// A sample's `static let code` holds SWIFT - whole `struct … : ContentView`
    /// declarations, several of them - and a scanner that reads those is reading
    /// an example rather than the program. Measured: five of the gallery's
    /// samples declare a view inside their snippet.
    private func sourceWithoutLiterals(_ source: String) -> String {
        var kept: [String] = []
        var inside = false

        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let markers = line.components(separatedBy: "\"\"\"").count - 1

            if markers % 2 == 1 {
                inside.toggle()
                kept.append("")
                continue
            }

            kept.append(inside ? "" : String(line))
        }

        return kept.joined(separator: "\n")
    }

    /// One declaration read out of a source file.
    private struct Declaration {
        let name: String
        let conformances: Set<String>
        let body: String
    }

    /// Every declaration of the kinds asked for, with what it conforms to and
    /// the text between its braces.
    private func declarations(in source: String, kinds: [String]) -> [Declaration] {
        var found: [Declaration] = []

        // The conformance list is OPTIONAL: a type may be made a view by an
        // extension elsewhere, and one that names nothing here still has to be
        // read. The caller decides what to do with an empty list.
        let pattern =
            #"(?m)^\s*(?:public |internal |private |fileprivate )?(?:final )?"#
            + #"(struct|class|protocol|extension)\s+([A-Za-z_][A-Za-z0-9_]*)\s*"#
            + #"(?:<[^>]*>)?\s*(?::\s*([^{]+))?\{"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let text = source as NSString

        for match in regex.matches(in: source, range: NSRange(location: 0, length: text.length)) {
            let kind = text.substring(with: match.range(at: 1))

            guard kinds.contains(where: { $0.hasSuffix(kind) }) else { continue }

            let name = text.substring(with: match.range(at: 2))
            let inherited =
                match.range(at: 3).location == NSNotFound
                ? "" : text.substring(with: match.range(at: 3))

            // The `where` of a generic declaration is not a conformance list.
            let listed = inherited.components(separatedBy: " where ")[0]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { $0.components(separatedBy: "<")[0] }

            guard let body = bracedBody(in: source, openingAt: match.range.location + match.range.length - 1)
            else { continue }

            found.append(Declaration(name: name, conformances: Set(listed), body: body))
        }

        return found
    }

    /// The text between a brace and the one that closes it.
    private func bracedBody(in source: String, openingAt offset: Int) -> String? {
        let characters = Array(source)

        guard offset < characters.count, characters[offset] == "{" else { return nil }

        var depth = 0
        var index = offset

        while index < characters.count {
            if characters[index] == "{" { depth += 1 }
            if characters[index] == "}" {
                depth -= 1

                if depth == 0 {
                    return String(characters[(offset + 1)..<index])
                }
            }

            index += 1
        }

        return nil
    }

    /// The lines written directly in a type - nested declarations and function
    /// bodies are deeper and belong to something else.
    private func ownLines(of body: String) -> [String] {
        var kept: [String] = []
        var depth = 0

        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)

            if depth == 0 { kept.append(text) }

            depth += text.filter { $0 == "{" }.count
            depth -= text.filter { $0 == "}" }.count
            depth = max(0, depth)
        }

        return kept
    }

}

/// Whether a declaration is private - `fileprivate` counts, being just as
/// unreachable from the file that builds the view.
private func isPrivate(_ line: String) -> Bool {
    line.contains("private ")
}

/// The name of the stored property a line declares with a default value, if it
/// declares one at all.
///
/// A computed property is not one - it has a brace rather than a value - and
/// neither is anything `static`, which belongs to the type rather than to an
/// instance a caller builds.
private func storedPropertyWithDefault(in line: String) -> String? {
    let text = line.trimmingCharacters(in: .whitespaces)

    guard !text.hasPrefix("//"), !text.contains("static ") else { return nil }

    // The `=` is the whole test, and it must come before any brace: a computed
    // property has a brace and no `=`, while a defaulted CLOSURE property has
    // both, in that order - `var handler: () -> Void = { }` is a default like
    // any other and was invisible while this rejected every line with a brace
    // in it. Nothing after the `=` is required either: a value written on the
    // NEXT line is still a default.
    let pattern = #"^(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |private |fileprivate )?"#
        + #"(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^={]+)?="#

    guard let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    else { return nil }

    return (text as NSString).substring(with: match.range(at: 1))
}

/// Every parameter list of a function of this name, as written.
private func parameterLists(of name: String, in body: String) -> [String] {
    let characters = Array(body)
    var found: [String] = []
    var index = body.startIndex

    while let range = body.range(of: name + "(", range: index..<body.endIndex) {
        index = range.upperBound

        var offset = body.distance(from: body.startIndex, to: range.upperBound) - 1
        var depth = 0
        let start = offset + 1

        while offset < characters.count {
            if characters[offset] == "(" { depth += 1 }
            if characters[offset] == ")" {
                depth -= 1

                if depth == 0 {
                    found.append(String(characters[start..<offset]))
                    break
                }
            }

            offset += 1
        }
    }

    return found
}

/// A parameter list cut at the commas that separate its parameters, rather
/// than at those inside a generic argument or a closure type.
private func parameters(in list: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var depth = 0

    for character in list {
        if "([<".contains(character) { depth += 1 }
        if ")]>".contains(character) { depth -= 1 }

        if character == ",", depth == 0 {
            parts.append(current)
            current = ""
        } else {
            current.append(character)
        }
    }

    parts.append(current)
    return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
}
