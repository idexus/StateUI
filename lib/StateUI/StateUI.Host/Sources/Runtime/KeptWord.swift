// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A kept value as the words a platform's store holds, the same on every host: a key's new value kept as its key's
/// kind where the application lists the key, as the value's own kind where it does not, and read back as its key's
/// kind.
/// Design: docs/design/host/runtime.md#kept-values
@_spi(Host) public enum KeptWord {
    /// The key's name and the words its new value is kept as, from the act `persistValue`'s arguments - the name,
    /// then the value; nil where they keep nothing.
    public static func kept(_ arguments: [HostValue], keys: [PersistentKey]) -> (name: String, word: String)? {
        guard arguments.count >= 2, let name = arguments[0].name else { return nil }

        let listed = keys.first { $0.name == name }
        guard let word = listed.map({ word(of: arguments[1], kind: $0.kind) }) ?? word(of: arguments[1]) else {
            return nil
        }
        return (name, word)
    }

    /// The values the core restores for `keys` from the words kept by each name: each read as its key's kind, where
    /// it reads as one.
    public static func restored(_ words: [String: String], for keys: [PersistentKey]) -> [String: HostValue] {
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
}
