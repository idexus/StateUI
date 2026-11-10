// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A library's public declarations as `lib/StateUI/exports/api` records them, a line each: its types, and each
/// member's name and parameters - what an example that cannot be compiled is held to.
/// Design: docs/design/README.md#the-examples-of-a-doc-comment
struct RecordedSurface {
    /// One parameter of a recorded member: its label (`_` for none), whether a call may leave it out, and whether it
    /// takes any number of arguments - a variadic or a pack.
    struct Parameter: Equatable {
        let label: String
        let defaulted: Bool
        let many: Bool
    }

    /// The types the surface declares, by name.
    private(set) var types: Set<String> = []

    /// Each member's parameter lists, by its type and name - nil for a property or a case with no values.
    private(set) var members: [String: [String: [[Parameter]?]]] = [:]

    /// The surface the recorded `files` hold together.
    init(files: [URL]) throws {
        for file in files {
            for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") {
                read(String(line))
            }
        }
    }

    /// Whether a member of the name `call` calls, on the type it names - on any type for a modifier - takes its
    /// arguments, or is a property or a case where it passes none.
    func takes(_ call: ExampleCall) -> Bool {
        let name = call.member
        let lists = call.type.map { members[$0]?[name] ?? [] } ?? members.values.flatMap { $0[name] ?? [] }
        return lists.contains { list in
            guard let list else { return call.arguments == nil }
            return call.arguments.map { Self.fits($0, list[...]) } ?? false
        }
    }

    /// Whether the arguments `given`, in order, fill `parameters`: each by its label - a trailing closure written
    /// first by any - a parameter left out only where it has a default, one taking many filled by any number.
    static func fits(_ given: [ExampleCall.Argument], _ parameters: ArraySlice<RecordedSurface.Parameter>) -> Bool {
        guard let parameter = parameters.first else { return given.isEmpty }
        let rest = parameters.dropFirst()
        if parameter.defaulted || parameter.many, fits(given, rest) { return true }
        guard let first = given.first, first.isTrailingFirst || first.label == parameter.label else { return false }
        if fits(Array(given.dropFirst()), rest) { return true }
        guard parameter.many else { return false }
        var taken = 1
        while taken < given.count, given[taken].label == "_", !given[taken].isTrailingFirst {
            taken += 1
            if fits(Array(given.dropFirst(taken)), rest) { return true }
        }
        return false
    }

    /// Reads one recorded line: `swift.<kind> <Type>.<member>(<labels>): <declaration>`, or a type's.
    private mutating func read(_ line: String) {
        let words = line.split(separator: " ", maxSplits: 2)
        guard words.count == 3, words[1].hasSuffix(":") else { return }
        let kind = words[0]
        let key = String(words[1].dropLast())
        if ["swift.struct", "swift.enum", "swift.class", "swift.protocol", "swift.typealias"].contains(kind) {
            types.insert(key)
            return
        }
        guard ["swift.method", "swift.type.method", "swift.init", "swift.enum.case", "swift.property",
               "swift.type.property"].contains(kind),
              let dot = key.firstIndex(of: ".") else { return }
        let type = String(key[..<dot])
        let member = key[key.index(after: dot)...]
        guard let open = member.firstIndex(of: "(") else {
            members[type, default: [:]][String(member), default: []].append(nil)
            return
        }
        let name = String(member[..<open])
        let labels = member[member.index(after: open)..<member.index(before: member.endIndex)]
            .split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        let declared = Self.parameters(of: String(words[2]))
        let parameters = labels.enumerated().map { index, label in
            let said = declared.count == labels.count ? declared[index] : nil
            return Parameter(label: label, defaulted: said?.defaulted ?? false, many: said?.many ?? false)
        }
        members[type, default: [:]][name, default: []].append(parameters)
    }

    /// Whether each parameter of a recorded declaration has a default, and whether it takes many.
    private static func parameters(of declaration: String) -> [(defaulted: Bool, many: Bool)] {
        let text = Array(declaration)
        var index = 0
        var angles = 0
        // The parameter list opens at the first `(` outside the generic clause.
        while index < text.count {
            if text[index] == "<" { angles += 1 }
            if text[index] == ">", index == 0 || text[index - 1] != "-" { angles -= 1 }
            if text[index] == "(", angles == 0 { break }
            index += 1
        }
        guard index < text.count else { return [] }
        return ExampleCall.topLevelParts(of: text, from: index, angles: true).map { part in
            let type = part.split(separator: ":", maxSplits: 1).last.map(String.init) ?? part
            return (
                defaulted: ExampleCall.topLevelParts(of: Array("(" + type + ")"), from: 0, separator: "=", angles: true)
                    .count > 1,
                many: type.contains("...") || type.trimmingCharacters(in: .whitespaces).hasPrefix("repeat "))
        }
    }
}
