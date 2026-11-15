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

    /// The value kept under `name`, read as `kind` (`KeptWord`); nil where none is, or it reads as none.
    public func value(named name: String, as kind: PersistentKind) -> HostValue? {
        words[name].flatMap { KeptWord.restored($0, as: kind) }
    }

    /// Keeps a key's new value as the act `persistValue` carries it - the key's name, then its value - by the rule
    /// every host keeps a value by (`KeptWord`); whether it was kept.
    @discardableResult
    public mutating func keep(_ arguments: [HostValue]) -> Bool {
        guard let kept = KeptWord.kept(arguments) else { return false }

        words[kept.name] = kept.word
        return true
    }

    /// A key or its words with a tab, a line's end and a backslash escaped - code point by code point, so what
    /// follows one, a combining mark included, stays apart from its escape.
    static func escaped(_ words: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in words.unicodeScalars {
            switch scalar {
            case "\\": result.append(contentsOf: #"\\"#.unicodeScalars)
            case "\t": result.append(contentsOf: #"\t"#.unicodeScalars)
            case "\n": result.append(contentsOf: #"\n"#.unicodeScalars)
            case "\r": result.append(contentsOf: #"\r"#.unicodeScalars)
            default: result.append(scalar)
            }
        }
        return String(result)
    }

    /// The words `escaped` wrote, read back code point by code point.
    static func unescaped(_ words: Substring) -> String {
        var result = String.UnicodeScalarView()
        var escaping = false
        for scalar in words.unicodeScalars {
            if escaping {
                result.append(scalar == "t" ? "\t" : scalar == "n" ? "\n" : scalar == "r" ? "\r" : scalar)
                escaping = false
            } else if scalar == "\\" {
                escaping = true
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }
}
