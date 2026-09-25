// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words a user types, kept to their bound and found by their characters, the same on every host.
/// Design: docs/design/host/runtime.md#typed-words
@_spi(Host) public enum InputWords {
    /// `words` cut to their first `bound` characters, where they run past it; nil where they fit, or there is no
    /// bound.
    public static func cut(_ words: String, toBound bound: Int?) -> String? {
        guard let bound, words.count > bound else { return nil }
        return String(words.prefix(max(0, bound)))
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
