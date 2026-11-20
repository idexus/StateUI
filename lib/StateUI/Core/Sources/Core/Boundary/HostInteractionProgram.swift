// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/views/interaction.md#what-the-host-is-handed

/// What the user's hand moves on an element, as the host meets it: plain values, one a number moved, compared as
/// they are - a program described again alike is the same program.
@_spi(Host) public struct HostInteractionProgram: Equatable, Sendable {
    /// The numbers moved, in written order.
    public var values: [HostInteractionValue]

    /// A program moving `values`.
    public init(values: [HostInteractionValue]) {
        self.values = values
    }
}

/// One number the hand moves: a lane of a state's channel, what moves it and how it rests.
@_spi(Host) public struct HostInteractionValue: Equatable, Sendable {
    /// The state's number: its channel.
    public var state: Int32

    /// Which of the state's numbers.
    public var lane: Int

    /// What of the hand moves it.
    public var input: HostInteractionInput

    /// How far down the hand may take it; minus infinity for no end that way.
    public var low: Double

    /// How far up the hand may take it; infinity for no end that way.
    public var high: Double

    /// Where it may rest; nil for anywhere in its range.
    public var snaps: HostInteractionSnaps?

    /// Whether it comes round, its range one turn.
    public var periodic: Bool

    /// Whether it grows as the hand moves left or up, or the fingers turn the other way.
    public var reversed: Bool

    /// How it goes on let go.
    public var release: InteractionRelease

    /// What a write of the program does to it while the hand holds it.
    public var programWrites: InteractionProgramWrites

    /// The lane `lane` of `state`, moved by `input`.
    public init(
        state: Int32, lane: Int, input: HostInteractionInput, low: Double = -.infinity, high: Double = .infinity,
        snaps: HostInteractionSnaps? = nil, periodic: Bool = false, reversed: Bool = false,
        release: InteractionRelease, programWrites: InteractionProgramWrites = .interrupt
    ) {
        self.state = state
        self.lane = lane
        self.input = input
        self.low = low
        self.high = high
        self.snaps = snaps
        self.periodic = periodic
        self.reversed = reversed
        self.release = release
        self.programWrites = programWrites
    }
}

/// What of the hand moves a number.
@_spi(Host) public enum HostInteractionInput: Equatable, Sendable {
    /// A hand one way - a finger or a pointer dragged, a trackpad's two fingers, a wheel - so far for a unit; one
    /// snap a hand where it `swipes`.
    case translation(Orientation, unit: InteractionUnit, swipes: Bool)

    /// Two fingers spreading: the number multiplied.
    case magnification

    /// Two fingers turning: a unit every so many degrees.
    case rotation(degreesPerUnit: Double)
}

/// Where a number may rest.
@_spi(Host) public enum HostInteractionSnaps: Equatable, Sendable {
    /// At these, lowest first - one turn's where the number comes round.
    case at([Double])

    /// At every multiple of the step, with no end.
    case every(Double)
}

/// How a patch changes what the hand moves on an element.
@_spi(Host) public enum HostInteractionUpdate: Equatable, Sendable {
    /// The program the element answers the hand by from now on.
    case replace(HostInteractionProgram)

    /// The hand moves nothing on the element.
    case clear
}
