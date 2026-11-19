// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a state's value stands on one frame, as the host shows it - reached
/// as `$fade.journey.sample`.
///
///     if let sample = $fade.journey.sample {
///         caption = "\(Int(sample.value * 100))%"      // where it has got to
///     }
///
/// Every field is of the same frame. A state nothing shows has no sample: its
/// value is the state's own, and nothing moves it.
/// Design: docs/design/core/journeys.md#the-sample
public struct JourneySample<Value: Walked>: Equatable, Sendable {
    /// Where the value stands on this frame.
    public let value: Value

    /// Where the host is taking it: the destination it had taken by this
    /// frame. A destination written since is the state's own value already.
    public let destination: Value

    /// How fast it is going, per second, lane by lane.
    public let velocity: Value

    /// The time of the display's frame the sample was read on, which every
    /// sample read on one frame shares.
    public let time: Duration
}

/// The host's last report of one channel, as the core keeps it: the lanes of value, destination and speed. It has
/// no time of its own: a channel standing still is the same sample on every frame.
/// Design: docs/design/core/journeys.md#the-sample
struct HostSample: Equatable {
    /// Where each lane stands.
    let value: [Double]

    /// Where the channel is taking each lane.
    let destination: [Double]

    /// Each lane's speed, per second.
    let velocity: [Double]

    /// The sample as a value's own type reads it on the frame at `time`, the display clock's milliseconds; nil
    /// where the lanes stand for none.
    func typed<Value: Walked>(_: Value.Type, at time: Double, showing shown: Value? = nil) -> JourneySample<Value>? {
        guard let value = shown ?? Value(carried: .lanes(value)),
              let destination = Value(carried: .lanes(destination)),
              let velocity = Value(carried: .lanes(velocity))
        else { return nil }

        return JourneySample(
            value: value, destination: destination, velocity: velocity,
            time: .microseconds(Int64((time * 1000).rounded())))
    }
}
