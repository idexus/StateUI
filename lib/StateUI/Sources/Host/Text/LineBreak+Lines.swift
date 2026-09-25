// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The lines a break allows, the same on every host.
/// Design: docs/design/host/tree.md#runs-of-words
@_spi(Host) extension LineBreak {
    /// Whether the words wrap onto more lines: word and character wrapping do; every other break keeps one line.
    public var wraps: Bool {
        self == .wordWrap || self == .characterWrap
    }

    /// Whether the words are cut short with an ellipsis where they do not fit.
    public var truncates: Bool {
        self == .headTruncation || self == .tailTruncation || self == .middleTruncation
    }

    /// The most lines the words stand on under `maximum`: one for a break that keeps one line, else `maximum` -
    /// nil, no bound, where it is none or no more than nothing.
    public func lines(maximum: Int?) -> Int? {
        wraps ? maximum.flatMap { $0 > 0 ? $0 : nil } : 1
    }
}
