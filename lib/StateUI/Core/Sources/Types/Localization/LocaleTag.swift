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
/// script capitalized, the region in capitals. It is read as BCP 47 writes it, in ASCII letters and digits: a
/// language of two or three letters and its extended languages, then a script, a region, variants, extensions and a
/// private use, each where it stands, a variant and a singleton once. Text that is no tag is kept as written, and
/// `isValid` says so.
///
/// Design: docs/design/types/localization.md#a-language-is-a-tag
public struct LocaleTag: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The tag in its standard spelling: `"zh-Hant-TW"`.
    public let identifier: String

    /// The language, in lower case: `"zh"`; empty where the text is no tag, or a private use alone (`x-…`).
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
        identifier = read.spelled.joined(separator: "-")
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
    public var writingDirection: WritingDirection {
        Self.rightToLeft.contains(likelyScript) ? .rightToLeft : .leftToRight
    }

    /// What a tag's parts say, each in its standard spelling and in order; nil where they are no tag.
    /// Design: docs/design/types/localization.md#a-language-is-a-tag
    private static func read(
        _ parts: [String]
    ) -> (language: String, script: String?, region: String?, spelled: [String])? {
        // ASCII as written: a letter outside it may lower into it (the Kelvin sign into `k`).
        guard parts.allSatisfy(isPart) else { return nil }
        let parts = parts.map { $0.lowercased() }
        guard let first = parts.first else { return nil }

        // A private use alone names no language.
        if first == "x" { return parts.count > 1 ? ("", nil, nil, parts) : nil }
        guard (2...3).contains(first.count), first.allSatisfy(\.isLetter) else { return nil }

        var at = 1
        var spelled = [first]
        func take(_ fits: (String) -> Bool, _ spelling: (String) -> String = { $0 }) -> String? {
            guard at < parts.count, fits(parts[at]) else { return nil }
            spelled.append(spelling(parts[at]))
            at += 1
            return spelled.last
        }
        for _ in 0..<3 {
            guard take({ $0.count == 3 && $0.allSatisfy(\.isLetter) }) != nil else { break }
        }
        let script = take({ $0.count == 4 && $0.allSatisfy(\.isLetter) }) { $0.prefix(1).uppercased() + $0.dropFirst() }
        let region = take(isRegion) { $0.uppercased() }
        // A variant and an extension's singleton each stand once; a private use's parts as often as written.
        var said: Set<String> = []
        while let variant = take({ $0.count >= 5 || ($0.count == 4 && $0.first?.isNumber == true) }) {
            guard said.insert(variant).inserted else { return nil }
        }
        // An extension's singleton, then a private use's `x`, each with a part at least after it.
        while let singleton = take({ $0.count == 1 && $0 != "x" }) {
            guard said.insert(singleton).inserted, take({ $0.count >= 2 }) != nil else { return nil }
            while take({ $0.count >= 2 }) != nil {}
        }
        if take({ $0 == "x" }) != nil {
            guard take({ _ in true }) != nil else { return nil }
            while take({ _ in true }) != nil {}
        }
        return at == parts.count ? (first, script, region, spelled) : nil
    }

    /// Whether `part` is one to eight ASCII letters and digits.
    private static func isPart(_ part: String) -> Bool {
        (1...8).contains(part.count) && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Whether `part` names a region: two letters, or three digits.
    private static func isRegion(_ part: String) -> Bool {
        (part.count == 2 && part.allSatisfy(\.isLetter)) || (part.count == 3 && part.allSatisfy(\.isNumber))
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
