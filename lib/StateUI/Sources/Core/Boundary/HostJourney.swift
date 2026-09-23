// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The complete image of one value the host animates.
///
/// A native host uses this representation instead of knowing how StateUI lays
/// a journey out in numeric state lanes. Values are arrays because the same
/// channel may carry a number, point, rectangle, insets or colour.
@_spi(Host) public struct HostJourney: Equatable, Sendable {
    /// Where the value stands on the current frame.
    public let value: [Double]

    /// Where the value is going.
    public let destination: [Double]

    /// Its current speed per second, lane by lane.
    public let velocity: [Double]

    /// The law carrying it to the destination.
    public let motion: Motion

    /// The continuation waiting for arrival, or nil when nobody waits.
    public let completion: Int?

    /// How many explicit stops this journey has received.
    public let stopped: UInt64

    /// A complete host-side image of a journey.
    public init(
        value: [Double],
        destination: [Double],
        velocity: [Double],
        motion: Motion,
        completion: Int?,
        stopped: UInt64
    ) {
        self.value = value
        self.destination = destination
        self.velocity = velocity
        self.motion = motion
        self.completion = completion
        self.stopped = stopped
    }
}

/// Which parts of a journey the host animates are reported back to StateUI.
@_spi(Host) public struct HostJourneyUpdate: OptionSet, Equatable, Sendable {
    /// The raw option bits.
    public let rawValue: UInt8

    /// Builds an update set from its raw option bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Where the value currently stands.
    public static let value = HostJourneyUpdate(rawValue: 1 << 0)

    /// Where the value is going.
    public static let destination = HostJourneyUpdate(rawValue: 1 << 1)

    /// How fast the value currently moves.
    public static let velocity = HostJourneyUpdate(rawValue: 1 << 2)

    /// The per-frame report emitted while a host motion is under way.
    public static let frame: HostJourneyUpdate = [.value, .velocity]

    /// The complete position of a journey when it is aimed, stopped or landed.
    public static let position: HostJourneyUpdate = [.value, .destination, .velocity]
}
