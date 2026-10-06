// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A sample's code as a file a reader could compile: its imports and types at the top, its state and helpers as
/// a view's members, and its view - one, or several one after another - as that view's body.
enum ListingFile {
    /// The file around `listing`.
    static func text(of listing: String) -> String {
        var imports: [String] = []
        var types: [String] = []
        var members: [String] = []
        var views: [String] = []
        var comments: [String] = []

        for statement in statements(of: listing) {
            guard let code = firstCode(of: statement) else {
                comments.append(statement)
                continue
            }

            let written = (comments + [statement]).joined(separator: "\n")
            comments = []

            switch kind(of: code) {
            case .import: imports.append(written)
            case .type: types.append(written)
            case .member, .function: members.append(written)
            case .view: views.append(written)
            }
        }

        // A function that reads none of the listing's properties is a helper of the file, as it is in the sample.
        let properties = members.flatMap { $0.matches(of: try! Regex(#"(?:var|let)\s+(\w+)"#)) }
            .compactMap { $0.output[1].substring.map(String.init) }
        let helpers = members.filter { member in
            firstCode(of: member).map(kind) == .function && !properties.contains { member.contains(try! Regex("\\b\($0)\\b")) }
        }
        types += helpers
        members.removeAll { helpers.contains($0) }

        var file = (["import StateUI", "@testable import GalleryUI"] + imports).joined(separator: "\n")
        file += "\n\n" + types.joined(separator: "\n\n") + "\n"
        guard !members.isEmpty || !views.isEmpty else { return file }

        let viewsBody = views.count == 1 ? views[0] : "VStack {\n\(indented(views.joined(separator: "\n")))\n}"
        let hasBody = members.contains { $0.contains(try! Regex(#"(?m)^\s*(?:\w+\s+)*var body\b"#)) }
        let body = hasBody || views.isEmpty ? "" : "\n\n    var body: some View {\n\(indented(viewsBody, by: 8))\n    }"
        let conformance = hasBody || !views.isEmpty ? ": View" : ""

        return file + "\nstruct Listing\(conformance) {\n\(indented(members.joined(separator: "\n\n")))\(body)\n}\n"
    }

    /// What a statement at the listing's outermost level is.
    private enum Kind {
        case `import`, type, member, function, view
    }

    /// A statement's first line of code, past its comments and compiler directives.
    private static func firstCode(of statement: String) -> String? {
        statement.split(separator: "\n").first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("#")
        }
        .map(String.init)
    }

    /// What the statement whose first line of code is `line` is, read past its attributes and modifiers.
    private static func kind(of line: String) -> Kind {
        var words = line.trimmingCharacters(in: .whitespaces)
            .replacing(try! Regex(#"@\w+(\([^)]*\))?\s*"#), with: "")
            .split(separator: " ")
        let modifiers: Set<Substring> = [
            "public", "private", "fileprivate", "internal", "final", "indirect", "static", "nonisolated",
            "mutating", "override", "lazy", "weak",
        ]
        let isStatic = words.contains("static")
        while let first = words.first, modifiers.contains(first) { words.removeFirst() }
        let keyword = words.first.map { String($0.prefix { $0.isLetter }) } ?? ""

        switch keyword {
        case "import": return .import
        case "struct", "enum", "class", "protocol", "extension", "actor", "typealias": return .type
        case "func": return isStatic ? .member : .function
        case "var", "let", "init", "subscript": return .member
        default: return line.hasPrefix("@") ? .member : .view
        }
    }

    /// The listing cut where a line at its outermost level begins a statement of its own; a `#if` and what it
    /// holds stand as one.
    private static func statements(of listing: String) -> [String] {
        var statements: [[Substring]] = []
        var depth = 0
        var conditions = 0

        for line in listing.split(separator: "\n", omittingEmptySubsequences: false) {
            let directive = line.trimmingCharacters(in: .whitespaces)
            defer {
                if directive.hasPrefix("#if") { conditions += 1 }
                if directive.hasPrefix("#endif") { conditions -= 1 }
            }
            let previous = statements.last?.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let continues = previous?.trimmingCharacters(in: .whitespaces).last.map { ",([=".contains($0) } == true
            let begins = depth == 0 && conditions == 0 && line.first.map { !" \t.)}]".contains($0) } == true
                && !continues

            if begins || statements.isEmpty {
                statements.append([line])
            } else {
                statements[statements.count - 1].append(line)
            }
            depth += balance(of: line)
        }

        return statements.map { $0.joined(separator: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// How many brackets `line` leaves open, its text and its comment left out.
    private static func balance(of line: Substring) -> Int {
        var balance = 0
        var quoted = false
        var escaped = false
        var previous: Character = " "

        for character in line {
            defer { previous = character }
            if quoted {
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" { quoted = false }
                continue
            }
            if character == "/", previous == "/" { break }

            switch character {
            case "\"": quoted = true
            case "{", "(", "[": balance += 1
            case "}", ")", "]": balance -= 1
            default: break
            }
        }

        return balance
    }

    private static func indented(_ text: String, by spaces: Int = 4) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : String(repeating: " ", count: spaces) + $0 }
            .joined(separator: "\n")
    }
}
