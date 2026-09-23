// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What each edge of a layout stays clear of - one answer for all four, or one
/// for each. What `.avoidsSafeArea` takes.
public enum SafeAreaEdges: Equatable, Sendable, HostRepresentable {
    /// The same answer for all four edges.
    case uniform(SafeArea)

    /// Each edge's own: left, top, right, bottom.
    case edges(left: SafeArea, top: SafeArea, right: SafeArea, bottom: SafeArea)

    /// One member, or the four in order, each a value of its own.
    public var propValue: PropValue {
        switch self {
        case .uniform(let area):
            return area.propValue
        case .edges(let left, let top, let right, let bottom):
            return .values([left.propValue, top.propValue, right.propValue, bottom.propValue])
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
              let left = SafeArea(propValue: values[0]), let top = SafeArea(propValue: values[1]),
              let right = SafeArea(propValue: values[2]), let bottom = SafeArea(propValue: values[3])
        else { return nil }

        self = .edges(left: left, top: top, right: right, bottom: bottom)
    }
}
