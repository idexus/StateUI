// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The words a user types, kept to their bound and found by their characters, the same on every host.
/// Design: docs/design/host/runtime.md#typed-words
@_spi(Host) public enum InputWords {
    /// `words` cut to their first `bound` characters, where they run past it; nil where they fit, or there is no
    /// bound.
    public static func cut(_ words: String, toBound bound: Int?) -> String? {
        guard let bound, words.count > bound else { return nil }
        return String(words.prefix(max(0, bound)))
    }

    /// What a field holds of the words the user left in it: in the field's case, then cut to its bound; nil where it
    /// holds them as they were typed - while an input method is `composing` them too: changed under it, the
    /// composition is lost, so they are held once it commits them.
    public static func held(_ typed: String, in textCase: TextCase?, toBound bound: Int?, composing: Bool) -> String? {
        guard !composing else { return nil }
        let cased = (textCase ?? .none).applied(to: typed)
        let held = cut(cased, toBound: bound) ?? cased
        return held == typed ? nil : held
    }

    /// What of `inserted` goes in beside `held`, where a toolkit asks before it inserts: in the field's case, then
    /// its first characters that fit within `bound` as the words will stand - a mark joining the letter before it
    /// counts with it - at the scalar `place` in `held`, their end where none is said; nil where it goes in as typed.
    public static func fitting(
        _ inserted: String, beside held: String, atScalar place: Int? = nil, in textCase: TextCase? = nil,
        toBound bound: Int?
    ) -> String? {
        let cased = (textCase ?? .none).applied(to: inserted)
        let going = bound.map { standing(cased, in: held, atScalar: place, within: max(0, $0)) } ?? cased
        return going == inserted ? nil : going
    }

    /// The longest first part of `words` that stands within `bound` characters once put into `held` at `place`:
    /// the words whole where they fit, else a part at most two characters past the room the held leave, as each
    /// seam can join one more.
    private static func standing(_ words: String, in held: String, atScalar place: Int?, within bound: Int) -> String {
        let scalars = held.unicodeScalars
        let at = scalars.index(scalars.startIndex, offsetBy: min(max(0, place ?? scalars.count), scalars.count))
        let before = String(scalars[..<at])
        let after = String(scalars[at...])
        func fits(_ part: Substring) -> Bool { (before + part + after).count <= bound }
        guard !fits(words[...]) else { return words }
        var part = words.prefix(min(words.count, max(0, bound - held.count) + 2))
        while !part.isEmpty, !fits(part) { part.removeLast() }
        return String(part)
    }

    /// A selection of `length` characters from the `start`th, in the UTF-16 units a toolkit counts in, each end
    /// kept within `words`.
    public static func utf16Selection(start: Int, length: Int, in words: String) -> (start: Int, length: Int) {
        let selected = selected(start: start, length: length, in: words)
        return (words[..<selected.startIndex].utf16.count, selected.utf16.count)
    }

    /// A selection of `length` characters from the `start`th, in the Unicode scalars a toolkit counts in, each end
    /// kept within `words`.
    public static func scalarSelection(start: Int, length: Int, in words: String) -> (start: Int, length: Int) {
        let selected = selected(start: start, length: length, in: words)
        return (words[..<selected.startIndex].unicodeScalars.count, selected.unicodeScalars.count)
    }

    /// The `length` characters from the `start`th: each end kept within `words` before any arithmetic, as a number
    /// a program hands may be any.
    private static func selected(start: Int, length: Int, in words: String) -> Substring {
        let count = words.count
        let first = min(max(0, start), count)
        let from = words.index(words.startIndex, offsetBy: first)
        return words[from..<words.index(from, offsetBy: min(max(0, length), count - first))]
    }
}
