// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/views/interaction.md#what-the-host-is-handed

/// What the user's hand moves on an element, as the host meets it: plain values, one a number moved, compared as
/// they are - a program described again alike is the same program.
@_spi(Host) public struct HostInteractionProgram: Equatable, Sendable {
    /// The numbers moved, in written order.
    public var values: [HostInteractionValue]

    /// The view's own press; nil for none.
    public var press: HostPress? {
        get { own.first?.press }
        set { own = Self.kept(Own(press: newValue, drag: drag)) }
    }

    /// The view's own drag; nil for none.
    public var drag: HostDrag? {
        get { own.first?.drag }
        set { own = Self.kept(Own(press: press, drag: newValue)) }
    }

    // The press and the drag stand out of line, none or one: a patch carries the program, and the mount copies a
    // patch at every level of the tree it goes down.
    // Design: docs/design/host/runtime.md#the-mounts-stack
    private var own: [Own]

    private struct Own: Equatable, Sendable {
        var press: HostPress?
        var drag: HostDrag?
    }

    private static func kept(_ own: Own) -> [Own] {
        own.press == nil && own.drag == nil ? [] : [own]
    }

    /// Whether the hand does nothing on the element.
    public var isEmpty: Bool { values.isEmpty && own.isEmpty }

    /// A program moving `values`, the view answering `press` and taken by `drag`.
    public init(press: HostPress? = nil, drag: HostDrag? = nil, values: [HostInteractionValue]) {
        self.values = values
        own = Self.kept(Own(press: press, drag: drag))
    }
}

/// A view's own press as the host meets it: the numbers of its presentation it moves, and what answers its
/// offset - the same press while that is the same object.
/// Design: docs/design/views/interaction.md#a-views-own-press-and-drag
@_spi(Host) public struct HostPress: Equatable, Sendable {
    /// The numbers of the view's presentation the press moves.
    public var values: PresentationValues

    /// What answers the press's offset.
    public var effect: HostPressEffect

    /// The spring the view comes after the answer on; nil for a view that is there at once.
    public var spring: HostLayoutBody?

    /// A press moving `values` by what `effect` answers, the view coming after it on `spring`.
    public init(values: PresentationValues, effect: HostPressEffect, spring: HostLayoutBody? = nil) {
        self.values = values
        self.effect = effect
        self.spring = spring
    }

    /// Whether two presses move the same numbers by the same object's answers on the same spring.
    public static func == (one: HostPress, other: HostPress) -> Bool {
        one.values == other.values && one.effect === other.effect && one.spring == other.spring
    }
}

/// What answers a press's offset: the application's effect, the newest its view was described with. One object
/// stands while the view does, so a view described again alike is told nothing and still answers by its newest
/// effect.
@_spi(Host) @MainActor public final class HostPressEffect: Sendable {
    /// The offset for a press as it stands.
    public var offset: @MainActor (PressInput) -> PresentationOffset

    /// An effect answering by `offset`.
    public init(_ offset: @escaping @MainActor (PressInput) -> PresentationOffset) {
        self.offset = offset
    }
}

/// A view's own drag as the host meets it: which ways the hand takes it, and when.
@_spi(Host) public struct HostDrag: Equatable, Sendable {
    /// Which ways the hand takes the view.
    public var axes: DragAxes

    /// When it takes it.
    public var begins: DragStart

    /// How letting the view go dismisses it; nil where it never does.
    public var dismissal: HostDismissal?

    /// A drag along `axes` beginning as `begins` says, dismissing its view as `dismissal` says.
    public init(axes: DragAxes, begins: DragStart, dismissal: HostDismissal? = nil) {
        self.axes = axes
        self.begins = begins
        self.dismissal = dismissal
    }
}

/// How a drag dismisses its view as the host meets it: the ways out, how far the view must go or be thrown, and
/// the law that carries a throw and paces the way out.
@_spi(Host) public struct HostDismissal: Equatable, Sendable {
    /// Which ways a throw dismisses the view.
    public var directions: SwipeDirections

    /// How far the view must go one of those ways, or be thrown, in points.
    public var threshold: Double

    /// The law a throw is carried by, and the pace of the way out.
    public var motion: Motion

    /// A dismissal `directions`' ways past `threshold` under `motion`.
    public init(directions: SwipeDirections, threshold: Double, motion: Motion) {
        self.directions = directions
        self.threshold = threshold
        self.motion = motion
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
