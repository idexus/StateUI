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
    /// holds them as they were typed.
    public static func held(_ typed: String, in textCase: TextCase?, toBound bound: Int?) -> String? {
        let cased = (textCase ?? .none).applied(to: typed)
        let held = cut(cased, toBound: bound) ?? cased
        return held == typed ? nil : held
    }

    /// What of `inserted` goes in beside `held`, where a toolkit asks before it inserts: in the field's case, then its
    /// first characters that fit within `bound`; nil where it goes in as typed.
    public static func fitting(
        _ inserted: String, beside held: String, in textCase: TextCase? = nil, toBound bound: Int?
    ) -> String? {
        let cased = (textCase ?? .none).applied(to: inserted)
        let fits = bound.map { held.count + cased.count > $0 ? String(cased.prefix(max(0, $0 - held.count))) : cased }
        let going = fits ?? cased
        return going == inserted ? nil : going
    }

    /// A selection of `length` characters from the `start`th, in the UTF-16 units a toolkit counts in, each end
    /// kept within `words`.
    public static func utf16Selection(start: Int, length: Int, in words: String) -> (start: Int, length: Int) {
        func units(_ characters: Int) -> Int {
            words.prefix(max(0, characters)).utf16.count
        }
        let from = units(start)
        return (from, units(max(0, start) + max(0, length)) - from)
    }
}
