// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What each edge of a layout stays clear of - one answer for all four, or one
/// for each. What `.avoidsSafeArea` takes.
public enum SafeAreaEdges: Equatable, Sendable, HostRepresentable {
    /// The same answer for all four edges.
    case uniform(SafeArea)

    /// Each edge's own: start, top, end, bottom - the start and the end as the element lays out.
    case edges(start: SafeArea, top: SafeArea, end: SafeArea, bottom: SafeArea)

    /// One member, or the four in order, each a value of its own.
    public var propValue: PropValue {
        switch self {
        case .uniform(let area):
            return area.propValue
        case .edges(let start, let top, let end, let bottom):
            return .values([start.propValue, top.propValue, end.propValue, bottom.propValue])
        }
    }

    /// The answer back: one member, or four in order - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if let area = SafeArea(propValue: propValue) {
            self = .uniform(area)
            return
        }

        guard let values = propValue.values, values.count == 4,
              let start = SafeArea(propValue: values[0]), let top = SafeArea(propValue: values[1]),
              let end = SafeArea(propValue: values[2]), let bottom = SafeArea(propValue: values[3])
        else { return nil }

        self = .edges(start: start, top: top, end: end, bottom: bottom)
    }
}
