// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A language tag (BCP 47): a language, and its script and region where they matter.
///
///     let tag: LocaleTag = "sr-Latn-RS"
///     tag.language    // "sr"
///     tag.script      // "Latn"
///     tag.region      // "RS"
///
/// Written with `-` or `_` and in any case, it is kept in the standard spelling: the language in lower case, the
/// script capitalized, the region in capitals. Text that is no tag is kept as written, and `isValid` says so.
///
/// Design: docs/design/types/localization.md#a-language-is-a-tag
public struct LocaleTag: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The tag in its standard spelling: `"zh-Hant-TW"`.
    public let identifier: String

    /// The language, in lower case: `"zh"`; empty where the text is no tag.
    public let language: String

    /// The script, capitalized, where the tag says one: `"Hant"`.
    public let script: String?

    /// The region, in capitals or as three digits, where the tag says one: `"TW"`, `"419"`.
    public let region: String?

    /// Whether the text was a tag at all.
    public let isValid: Bool

    /// Reads a tag; a POSIX locale such as `pl_PL.UTF-8@euro` reads as its language and region.
    public init(_ text: String) {
        let core = text.split(whereSeparator: { $0 == "." || $0 == "@" }).first.map(String.init) ?? ""
        let parts = core.split(separator: "-", omittingEmptySubsequences: false)
            .flatMap { $0.split(separator: "_", omittingEmptySubsequences: false) }
            .map(String.init)
        guard let read = Self.read(parts) else {
            (identifier, language, script, region, isValid) = (text, "", nil, nil, false)
            return
        }

        (language, script, region, isValid) = (read.language, read.script, read.region, true)
        identifier = ([read.language] + [read.script, read.region].compactMap { $0 } + read.rest).joined(separator: "-")
    }

    /// A tag written as a literal: `"pl-PL"`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The tag in its standard spelling.
    public var description: String { identifier }

    /// The script the tag is written in: the one it says, or the one its language is written in where it says
    /// none - `sr` is Cyrillic, `zh-TW` Traditional Chinese.
    public var likelyScript: String {
        if let script { return script }
        if language == "zh" { return ["TW", "HK", "MO"].contains(region ?? "") ? "Hant" : "Hans" }
        return Self.scripts[language] ?? "Latn"
    }

    /// The way the tag's script is written: right to left for Arabic, Hebrew and their kin.
    public var direction: LayoutDirection {
        Self.rightToLeft.contains(likelyScript) ? .rightToLeft : .leftToRight
    }

    private static func read(_ parts: [String]) -> (language: String, script: String?, region: String?, rest: [String])? {
        guard let first = parts.first, (2...3).contains(first.count), first.allSatisfy(\.isLetter),
              parts.allSatisfy({ !$0.isEmpty && $0.count <= 8 && $0.allSatisfy { $0.isLetter || $0.isNumber } })
        else { return nil }

        var rest = parts.dropFirst()
        var script: String?
        var region: String?
        if let next = rest.first, next.count == 4, next.allSatisfy(\.isLetter) {
            script = next.prefix(1).uppercased() + next.dropFirst().lowercased()
            rest = rest.dropFirst()
        }
        if let next = rest.first,
           (next.count == 2 && next.allSatisfy(\.isLetter)) || (next.count == 3 && next.allSatisfy(\.isNumber)) {
            region = next.uppercased()
            rest = rest.dropFirst()
        }
        return (first.lowercased(), script, region, rest.map { $0.lowercased() })
    }

    /// The scripts of languages not written in Latin, where a tag says none.
    private static let scripts: [String: String] = [
        "am": "Ethi", "ar": "Arab", "be": "Cyrl", "bg": "Cyrl", "bn": "Beng", "ckb": "Arab", "dv": "Thaa",
        "el": "Grek", "fa": "Arab", "gu": "Gujr", "he": "Hebr", "hi": "Deva", "hy": "Armn", "ja": "Jpan",
        "ka": "Geor", "kk": "Cyrl", "km": "Khmr", "kn": "Knda", "ko": "Kore", "ky": "Cyrl", "lo": "Laoo",
        "mk": "Cyrl", "ml": "Mlym", "mn": "Cyrl", "mr": "Deva", "my": "Mymr", "ne": "Deva", "pa": "Guru",
        "ps": "Arab", "ru": "Cyrl", "sd": "Arab", "si": "Sinh", "sr": "Cyrl", "ta": "Taml", "te": "Telu",
        "th": "Thai", "ug": "Arab", "uk": "Cyrl", "ur": "Arab", "yi": "Hebr",
    ]

    /// The scripts written right to left.
    private static let rightToLeft: Set<String> = ["Adlm", "Arab", "Hebr", "Mand", "Nkoo", "Rohg", "Samr", "Syrc", "Thaa"]
}
