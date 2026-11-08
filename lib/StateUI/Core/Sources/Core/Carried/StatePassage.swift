// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a state crosses to the host for a property a control takes from it - what `setValue(_:on:as:)` is told. A
/// state takes only the ways its value can: a journey where the host can walk it, a feed where it is numbers.
///
///     setValue(RatingBarContract.rating, on: state, as: .journey)
public struct StatePassage<Value>: Equatable, Sendable {
    /// The four ways, which the state's value narrows.
    enum Way: Equatable, Sendable {
        case oneWay, twoWay, feed, journey
    }

    /// The way this passage is.
    let way: Way

    /// Written to the host as it stands; nothing comes back.
    public static var oneWay: Self { Self(way: .oneWay) }

    /// Written to the host as it stands, and what the control reports lands back on the state - a switch flipped,
    /// a choice made.
    public static var twoWay: Self { Self(way: .twoWay) }

    /// Which way the value crosses at the host.
    var mode: StateMode {
        switch way {
        case .oneWay: .out
        case .twoWay, .journey: .inOut
        case .feed: .in
        }
    }

    /// Which of the host's doors a value of numbers goes through.
    var kind: StateKind {
        switch way {
        case .oneWay, .twoWay: .plain
        case .feed: .feed
        case .journey: .property
        }
    }
}

extension StatePassage where Value: LaneValue {
    /// Written by the host alone, and read by the application - the frame a layout settled on.
    public static var feed: Self { Self(way: .feed) }
}

extension StatePassage where Value: Walked {
    /// Walked by the host along the state's journey, and where the walk has got to reported back - so
    /// `$x.journey.move(to:)` moves the property.
    public static var journey: Self { Self(way: .journey) }
}
