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
        KeptWord.restored(words, for: keys)
    }

    /// Keeps a key's new value as the act `persistValue` carries it - the key's name, then its value - by the rule
    /// every host keeps a value by (`KeptWord`); whether it was kept.
    @discardableResult
    public mutating func keep(_ arguments: [HostValue], keys: [PersistentKey]) -> Bool {
        guard let kept = KeptWord.kept(arguments, keys: keys) else { return false }

        words[kept.name] = kept.word
        return true
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
