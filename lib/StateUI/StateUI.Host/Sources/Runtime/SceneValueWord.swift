// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A value a scene keeps as the words a host writes it in: its kind's letter, then its words.
enum SceneValueWord {
    /// A value as its words, its kind's letter first; nil for a value no scene keeps.
    static func word(of value: HostValue) -> String? {
        if let bool = value.bool { return bool ? "btrue" : "bfalse" }
        if let number = value.number { return "n\(number)" }
        return value.string.map { "s\($0)" }
    }

    /// The value words of `word`'s kind read as; nil for words of no kind.
    static func value(_ word: String) -> HostValue? {
        let words = String(word.dropFirst())
        switch word.first {
        case "b": return .bool(words == "true")
        case "n": return Double(words).map { .number($0) }
        case "s": return .string(words)
        default: return nil
        }
    }
}
