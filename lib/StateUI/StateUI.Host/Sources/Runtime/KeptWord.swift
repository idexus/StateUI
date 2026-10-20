// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A kept value as the words a platform's store holds, the same on every host: a key's new value kept as the words
/// of its own kind, and read back as the kind of the key that reads it.
/// Design: docs/design/host/runtime.md#kept-values
@_spi(Host) public enum KeptWord {
    /// The key's name and the words its new value is kept as, from the act `persistValue`'s arguments - the name,
    /// then the value; nil where they keep nothing.
    public static func kept(_ arguments: [HostValue]) -> (name: String, word: String)? {
        guard arguments.count >= 2, let name = arguments[0].name, let word = word(of: arguments[1]) else { return nil }
        return (name, word)
    }

    /// The value `word` holds, read as `kind`; nil where it reads as none.
    public static func restored(_ word: String, as kind: PersistentKind) -> HostValue? {
        switch kind {
        case .boolean: .bool(word == "true")
        case .integer, .number: Double(word).map(HostValue.number)
        case .text: .string(word)
        }
    }

    /// A value as the words of its own kind; nil for a value no key keeps.
    static func word(of value: HostValue) -> String? {
        if let bool = value.bool { return bool ? "true" : "false" }
        if let number = value.number {
            // A whole number is written whole, so a key of either kind reads it back.
            return number == number.rounded() && abs(number) < 1e15 ? String(Int64(number)) : String(number)
        }
        return value.string
    }
}
