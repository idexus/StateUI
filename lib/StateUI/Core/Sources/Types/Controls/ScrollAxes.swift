// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// The ways a `ScrollView` scrolls: across, down, both - `.all` - or none, `[]`, where nothing scrolls and the
/// scroller stands at its beginning.
///
///     ScrollView { … }.axes(.horizontal)
///     ScrollView { … }.axes(.all)
///
/// A scroller that says none of it scrolls down.
public struct ScrollAxes: OptionSet, Sendable {
    /// The axis bits.
    public let rawValue: Int32

    /// From the raw bits. `.vertical`, `.horizontal` and `.all` are the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Sideways.
    public static let horizontal = ScrollAxes(rawValue: 1 << 0)

    /// Up and down - what a scroller does when nothing is said.
    public static let vertical = ScrollAxes(rawValue: 1 << 1)

    /// Both ways at once.
    public static let all: ScrollAxes = [.horizontal, .vertical]
}

extension ScrollAxes: HostRepresentable {}
extension ScrollAxes: StateChoice {}
