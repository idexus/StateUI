// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// The edges of a layout that run under what stands over its page - the bars,
/// a notch, the home indicator, the on-screen keyboard. What `.ignoresSafeArea`
/// takes.
///
///     Grid { … }.ignoresSafeArea([.start, .top])
///
/// The start and the end are the layout's own: right to left, the start is the
/// right edge.
public struct SafeAreaEdges: OptionSet, Sendable {
    /// The edge bits.
    public let rawValue: Int32

    /// From the raw bits. `.top`, `[.start, .top]` and `.all` are the ordinary
    /// way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// No edge: the layout stands clear of everything over its page - what it
    /// does when nothing is said.
    public static let none = SafeAreaEdges([])

    /// The edge a line of words starts from.
    public static let start = SafeAreaEdges(rawValue: 1 << 0)

    /// The top edge.
    public static let top = SafeAreaEdges(rawValue: 1 << 1)

    /// The edge a line of words ends at.
    public static let end = SafeAreaEdges(rawValue: 1 << 2)

    /// The bottom edge.
    public static let bottom = SafeAreaEdges(rawValue: 1 << 3)

    /// The start and the end.
    public static let horizontal: SafeAreaEdges = [.start, .end]

    /// The top and the bottom.
    public static let vertical: SafeAreaEdges = [.top, .bottom]

    /// Every edge: edge to edge.
    public static let all: SafeAreaEdges = [.start, .top, .end, .bottom]
}

extension SafeAreaEdges: HostRepresentable {}
extension SafeAreaEdges: StateChoice {}
