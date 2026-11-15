// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A call an example makes - `Type.member(…)` or a modifier `.member(…)` - read from its text: what it calls, and
/// the labels of its arguments, its trailing closures among them.
/// Design: docs/design/README.md#the-examples-of-a-doc-comment
struct ExampleCall {
    /// One argument: its label, `_` for none; a trailing closure written first fills a parameter of any label.
    struct Argument: Equatable {
        let label: String
        var isTrailingFirst = false
    }

    /// The type named before the member, nil for a modifier.
    let type: String?

    /// The member called.
    let member: String

    /// Its arguments in order; nil where it is read and not called.
    let arguments: [Argument]?

    /// The line of the example the call stands on, from 0.
    let line: Int

    /// The calls `text` makes on a type a surface declares - `StateUIActs.add(…)` - where `types` holds the type.
    static func qualified(in text: String, types: Set<String>) -> [ExampleCall] {
        let characters = Array(text)
        var calls: [ExampleCall] = []
        var index = 0
        while index < characters.count {
            guard characters[index].isUppercase, index == 0 || !isIdentifier(characters[index - 1]) else {
                index += 1
                continue
            }
            let type = identifier(in: characters, at: index)
            let dot = index + type.count
            index = dot
            guard types.contains(type), dot < characters.count, characters[dot] == ".",
                  dot + 1 < characters.count, characters[dot + 1].isLowercase else { continue }
            let member = identifier(in: characters, at: dot + 1)
            guard member != "self" else { continue }
            calls.append(ExampleCall(
                type: type, member: member, arguments: arguments(in: characters, after: dot + 1 + member.count),
                line: line(of: dot, in: characters)))
        }
        return calls
    }

    /// The modifiers a fragment - an example starting with `.` - chains: each line starting with `.` as far in as
    /// its first line, an argument's own lines further in left out.
    static func modifiers(in text: String) -> [ExampleCall] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let indent = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.prefix { $0 == " " }.count }
        var calls: [ExampleCall] = []
        var offset = 0
        let characters = Array(text)
        for (number, line) in lines.enumerated() {
            defer { offset += line.count + 1 }
            let own = line.prefix { $0 == " " }.count
            guard own == indent, line.dropFirst(own).first == "." else { continue }
            let start = offset + own + 1
            let member = identifier(in: characters, at: start)
            guard !member.isEmpty else { continue }
            calls.append(ExampleCall(
                type: nil, member: member, arguments: arguments(in: characters, after: start + member.count),
                line: number))
        }
        return calls
    }

    /// The call as an example writes it: `.member(label:_:)`, `Type.member {}`.
    var said: String {
        let labels = arguments.map { "(" + $0.map { $0.isTrailingFirst ? "{}" : $0.label + ":" }.joined() + ")" } ?? ""
        return (type ?? "") + "." + member + labels
    }

    /// The arguments of a call whose name ends before `index`: those in its parentheses, then its trailing closures;
    /// nil where neither follows.
    private static func arguments(in text: [Character], after index: Int) -> [Argument]? {
        var at = index
        var given: [Argument]?
        if at < text.count, text[at] == "(" {
            given = topLevelParts(of: text, from: at).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { Argument(label: label(of: $0) ?? "_") }
            at = closing(text, from: at) + 1
        }
        var first = true
        while true {
            var next = at
            while next < text.count, text[next] == " " || (!first && text[next] == "\n") { next += 1 }
            var label: String?
            if !first {
                let name = identifier(in: text, at: next)
                guard !name.isEmpty, next + name.count < text.count, text[next + name.count] == ":" else { break }
                label = name
                next += name.count + 1
                while next < text.count, text[next] == " " { next += 1 }
            }
            guard next < text.count, text[next] == "{" else { break }
            given = (given ?? []) + [Argument(label: label ?? "_", isTrailingFirst: first)]
            at = closing(text, from: next) + 1
            first = false
        }
        return given
    }

    /// The parts between `text[open]`, an opening bracket, and the bracket closing it, split at each `separator`
    /// standing outside every inner bracket, string and closure - and generic clause, where `angles`: a declaration's
    /// `<` opens one, an example's may compare.
    static func topLevelParts(
        of text: [Character], from open: Int, separator: Character = ",", angles: Bool = false
    ) -> [String] {
        var parts: [String] = []
        var part = ""
        var depth = 0
        var index = open
        while index < text.count {
            let character = text[index]
            if character == "\"" {
                let end = closingQuote(text, from: index)
                part += String(text[index...min(end, text.count - 1)])
                index = end + 1
                continue
            }
            if "([{".contains(character) || (angles && character == "<" && depth > 0) { depth += 1 }
            if ")]}".contains(character) || (angles && character == ">" && depth > 1 && text[index - 1] != "-") {
                depth -= 1
            }
            if depth == 0 { break }
            if depth == 1, character == separator {
                parts.append(part)
                part = ""
            } else if index != open {
                part.append(character)
            }
            index += 1
        }
        return part.isEmpty && parts.isEmpty ? [] : parts + [part]
    }

    /// The index of the bracket closing `text[open]`; the last index where none does.
    private static func closing(_ text: [Character], from open: Int) -> Int {
        var depth = 0
        var index = open
        while index < text.count {
            if text[index] == "\"" {
                index = closingQuote(text, from: index) + 1
                continue
            }
            if "([{".contains(text[index]) { depth += 1 }
            if ")]}".contains(text[index]) { depth -= 1 }
            if depth == 0 { return index }
            index += 1
        }
        return text.count - 1
    }

    /// The index of the quote closing the string opened at `open`.
    private static func closingQuote(_ text: [Character], from open: Int) -> Int {
        var index = open + 1
        while index < text.count, text[index] != "\"" {
            index += text[index] == "\\" ? 2 : 1
        }
        return index
    }

    /// The label an argument's text opens with - `label: value` - nil for none.
    private static func label(of argument: String) -> String? {
        let trimmed = Array(argument.drop { $0 == " " || $0 == "\n" })
        let name = identifier(in: trimmed, at: 0)
        guard !name.isEmpty, name.count < trimmed.count, trimmed[name.count] == ":",
              name.count + 1 >= trimmed.count || trimmed[name.count + 1] != ":" else { return nil }
        return name
    }

    private static func identifier(in text: [Character], at start: Int) -> String {
        var end = start
        while end < text.count, isIdentifier(text[end]) { end += 1 }
        return start < text.count ? String(text[start..<end]) : ""
    }

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private static func line(of index: Int, in text: [Character]) -> Int {
        text[..<index].filter { $0 == "\n" }.count
    }
}
