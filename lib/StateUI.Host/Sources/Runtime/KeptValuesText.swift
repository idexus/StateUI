// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The application's kept values as the text of a file of the host's own, for a platform that keeps no store an
/// application can use: a line a key, its name and its words apart by a tab. The same values write the same text.
/// Design: docs/design/host/runtime.md#kept-values
@_spi(Host)
public struct KeptValuesText: Equatable, Sendable {
    /// Each key's words, by its name.
    public private(set) var words: [String: String]

    /// The values `text` holds; a line that is no key and words is passed over.
    public init(_ text: String) {
        words = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            words[Self.unescaped(parts[0])] = Self.unescaped(parts[1])
        }
    }

    /// The text holding the values, their keys in order.
    public var text: String {
        words.keys.sorted().map { "\(Self.escaped($0))\t\(Self.escaped(words[$0]!))\n" }.joined()
    }

    /// The values the core restores for `keys`: each key's words read as its kind, where they read as one.
    public func restored(for keys: [PersistentKey]) -> [String: HostValue] {
        var restored: [String: HostValue] = [:]
        for key in keys {
            guard let word = words[key.name] else { continue }
            switch key.kind {
            case .boolean: restored[key.name] = .bool(word == "true")
            case .integer, .number: if let number = Double(word) { restored[key.name] = .number(number) }
            case .text: restored[key.name] = .string(word)
            }
        }
        return restored
    }

    /// Keeps a key's new value as the act `persistValue` carries it - the key's name, then its value - as its key's
    /// kind where `keys` lists the key, and as the value's own kind where it does not; whether it was kept.
    @discardableResult
    public mutating func keep(_ arguments: [HostValue], keys: [PersistentKey]) -> Bool {
        guard arguments.count >= 2, let name = arguments[0].name else { return false }

        let listed = keys.first { $0.name == name }
        guard let word = listed.map({ Self.word(of: arguments[1], kind: $0.kind) }) ?? Self.word(of: arguments[1])
        else { return false }

        words[name] = word
        return true
    }

    /// A value of a key the application does not list, as the words of its own kind; nil for a value no key keeps.
    static func word(of value: HostValue) -> String? {
        if let bool = value.bool { return bool ? "true" : "false" }
        if let number = value.number { return String(number) }
        return value.string
    }

    /// A value as the words its kind reads back; nil for a value of another kind.
    static func word(of value: HostValue, kind: PersistentKind) -> String? {
        switch kind {
        case .boolean: value.bool.map { $0 ? "true" : "false" }
        case .integer: value.number.map { String(Int64($0)) }
        case .number: value.number.map { String($0) }
        case .text: value.string
        }
    }

    /// A key or its words with a tab, a line's end and a backslash escaped.
    static func escaped(_ words: String) -> String {
        words.replacing("\\", with: "\\\\").replacing("\t", with: "\\t").replacing("\n", with: "\\n")
            .replacing("\r", with: "\\r")
    }

    static func unescaped(_ words: Substring) -> String {
        var result = ""
        var escaping = false
        for character in words {
            if escaping {
                result.append(character == "t" ? "\t" : character == "n" ? "\n" : character == "r" ? "\r" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
