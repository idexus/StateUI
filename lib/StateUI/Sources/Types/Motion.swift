// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// HOW A VALUE MOVES WHEN IT CHANGES.
//
// The tree describes where the interface is GOING; the host's engine is how the
// screen catches up. This is the whole of what an author says about that
// catching up - one vocabulary, used in four places and meaning the same thing
// in all of them:
//
//     application.motion = …        what everything moves at, by default
//     .motion(.none)                what THIS element does instead
//     @State(motion: .none) var x   what THIS value does instead, wherever it is shown
//     $fade.journey.move(to: 0.1, .spring())   what THIS write does instead
//
// The renderer resolves these choices into `HostTransition` or
// `HostLayoutMotion`. A native host advances the presentation on its display
// frames while the tree keeps the destination.
//
// The two laws are the two shapes a movement can have. A LENGTH is a movement
// that takes as long as it is told, whatever the distance. A SPRING is a
// movement with no length at all: it answers as quickly as its response says
// and settles when it is done, which is what makes an interrupted one carry on
// rather than start over.
//
// BOTH OF THEM ARRIVE AT WHAT THE TREE SAID, and that is the whole reason there
// are only two. A law with no destination - a throw, bled off, coming to rest
// wherever its speed runs out - leaves the screen showing a value nothing ever
// described, and an absent field means unchanged, so nothing could ever put it
// right. The physics of a throw lives where a throw is: in the scroller.
//
// `.custom` is not a third law but a third WALKER: the host walks nothing and
// an application engine writes where the value is, frame by frame, towards a
// destination the state still holds. It is said where the value is declared -
// `@State(motion: .custom)` - because ownership of the walk is fixed when that
// state is first registered with the host.

/// How a value moves when it changes in StateUI.
///
/// A change is a MOTION by default - assign a state and the control travels
/// there - and this is what says how:
///
///     VStack { … }.motion(.spring(response: 260))
///
///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
///
/// `.none` is how something snaps: the value is written and the screen is
/// already showing it. `.custom` hands the walk to an engine of your own.
/// Every other case names a law and the numbers it needs.
public struct Motion: Equatable, Sendable {
    /// Which law a movement follows in the host contract.
    ///
    /// The numbers belong to StateUI's stable Wire vocabulary: declaration
    /// order from 0, fixed forever. See Types/Easing.swift.
    public enum Law: Int32, Sendable {
        /// A stated length on a stated curve.
        case eased = 0

        /// A mass on a spring - no length, only a response.
        case spring = 1
    }

    /// The law this motion travels under.
    public let law: Law

    /// Milliseconds: how long an eased motion takes, or a spring's response.
    public let millis: UInt32

    /// The curve an eased motion follows.
    public let curve: Easing

    /// A spring's damping. Nought where the law has no use for one.
    public let factor: Double

    /// Whether this motion is the one its element resolves to rather than one
    /// of its own.
    public let isInherited: Bool

    /// Whether an application engine advances the value instead of the host;
    /// see `custom`.
    public let isCustom: Bool

    /// Whatever the element this is written on resolves to - the element's own
    /// motion, or the application's, or this library's.
    ///
    /// What a write means when it says nothing about how to travel, which is
    /// what makes `move(to:)` and a plain assignment agree about the motion
    /// and differ only in being awaited.
    public static let inherited = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: true, isCustom: false)

    /// No motion: the value is written and the screen is already showing it.
    ///
    /// The escape from motion. An ordinary property that snaps carries no
    /// `HostTransition` beside its target value.
    public static let none = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false, isCustom: false)

    /// The walk is YOURS: a write moves the destination alone, the host walks
    /// nothing, and an engine of your own writes where the value is and how
    /// fast it is going, frame by frame, reading the destination back.
    ///
    ///     @State(motion: .custom) private var ball = 0.0
    ///
    ///     ColorBox()
    ///         .translationY($ball)
    ///         .engine(following: $ball) { cycle in
    ///             let journey = $ball.journey
    ///             let pull = (journey.destination - journey.value) * 0.2
    ///             journey.velocity += pull
    ///             journey.value += journey.velocity * cycle.elapsed / 1000
    ///             return abs(pull) > 0.01 ? .again : .wait
    ///         }
    ///
    /// Not `.none`, which lands the value where it was sent: here a write to
    /// the state changes where it is GOING and nothing else, and where it IS
    /// stays put until the engine moves it. Said where the value is declared,
    /// because the initial host registration fixes which side advances it.
    public static let custom = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false, isCustom: true)

    /// A movement of a stated length on a stated curve.
    ///
    ///     .motion(.eased(400, .cubicOut))
    ///
    /// It takes as long as it is told however far it has to go, which is what
    /// makes it the right law for something whose distance the author knows -
    /// a fade, a page that slides in, a card that turns over.
    ///
    /// - Parameters:
    ///   - length: how long it takes, in milliseconds.
    ///   - curve: how it spends that time. `.cubicOut` arrives gently, which is
    ///     what almost everything on screen wants.
    /// - Returns: the motion.
    public static func eased(_ length: UInt, _ curve: Easing = .cubicOut) -> Motion {
        Motion(
            law: .eased,
            millis: UInt32(truncatingIfNeeded: length),
            curve: curve,
            factor: 0,
            isInherited: false,
            isCustom: false)
    }

    /// A mass on a spring, which answers a change rather than timing it.
    ///
    ///     .motion(.spring(response: 260))
    ///
    /// It has no length: a spring settles when it is done, and one whose target
    /// moves mid-walk simply carries on from the speed it had. That is what
    /// makes it right for anything a reader can interrupt - a card being
    /// dragged, a value they are still choosing.
    ///
    /// - Parameters:
    ///   - response: how quickly it answers, in milliseconds. Smaller is
    ///     snappier.
    ///   - damping: 1 comes to rest without overshooting. Below 1 overshoots
    ///     and rings, which is a deliberate purchase and never a default: half
    ///     a card's worth of wobble is what a reader reads as a mistake.
    /// - Returns: the motion.
    public static func spring(response: UInt = 300, damping: Double = 1) -> Motion {
        Motion(
            law: .spring,
            millis: UInt32(truncatingIfNeeded: max(response, 1)),
            curve: .linear,
            factor: max(damping, 0.05),
            isInherited: false,
            isCustom: false)
    }

    /// Whether this motion moves nothing - the value simply arrives.
    var isNothing: Bool {
        !isInherited && !isCustom && law == .eased && millis == 0
    }

    /// This motion, or `fallback` where this is the inherited one.
    func resolved(against fallback: Motion) -> Motion {
        isInherited ? fallback : self
    }

    /// What everything moves at unless something says otherwise.
    ///
    /// StateUI uses one 200-millisecond cubic-out soft stop for ordinary changes
    /// and scroller landings.
    public static let standard = Motion.eased(200, .cubicOut)
}

/// Which groups of a view's values a StateUI motion affects.
///
/// A motion written on a view is about all of them unless it names some:
///
///     VStack { … }
///         .motion(.spring(response: 240))
///         .motion(.none, .size)
///
/// That stack's children cross to their new places on a spring and take their
/// new SIZE at once, which is what a panel whose content changes shape wants -
/// a view growing out of nothing is the one movement a reader reads as a fault.
///
/// The names are groups rather than single properties, because that is how a
/// reader thinks about what they are watching. Each group covers semantic
/// StateUI properties. A property in none of them is reached by the plain form
/// and by `.all`, which is what almost every motion there is says.
///
/// A selective rule steers properties the tree describes. Host-owned
/// presentation changes without an ordinary `Prop` - child placement, visual
/// states, and showing or hiding - use the base `.motion(_:)`. Placement is
/// also split into `.place`, `.width` and `.height`, so a selective rule can
/// snap only those lanes.
public struct MotionValues: OptionSet, Sendable {
    /// The members this set holds.
    public let rawValue: Int

    /// A set from its members' bits, which is what an OptionSet is made of.
    ///
    /// - Parameter rawValue: the bits.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// How see-through the view is: `.opacity`.
    public static let opacity = MotionValues(rawValue: 1 << 0)

    /// Every colour it wears - a background, a text colour, a track, a thumb.
    ///
    /// Read off the VALUE rather than from a list of property names, so a
    /// colour added to this library later is in here the day it arrives.
    public static let colour = MotionValues(rawValue: 1 << 1)

    /// How wide it is: `.width`, `.minimumWidth`,
    /// `.maximumWidth` and `.width`.
    public static let width = MotionValues(rawValue: 1 << 2)

    /// How tall it is: `.height`, `.minimumHeight`,
    /// `.maximumHeight` and `.height`.
    public static let height = MotionValues(rawValue: 1 << 3)

    /// Both dimensions, plus the lengths its own shape is drawn with:
    /// `.cornerRadius`, `.strokeWidth`, `.borderWidth`, `.radiusX` and
    /// `.radiusY`.
    public static let size: MotionValues = [.width, .height]

    /// Where it SITS: host-arranged placement and `.translationX` or
    /// `.translationY`.
    public static let place = MotionValues(rawValue: 1 << 4)

    /// How it is turned and how big it is DRAWN, which is not how big it is:
    /// `.scale`, `.scaleX`, `.scaleY`, `.rotation`, `.rotationX`, `.rotationY`,
    /// `.pivotX` and `.pivotY`.
    public static let transform = MotionValues(rawValue: 1 << 5)

    /// The room it keeps around and inside itself: `.padding`, `.margin`,
    /// `.spacing`, `.rowSpacing` and `.columnSpacing`.
    public static let spacing = MotionValues(rawValue: 1 << 6)

    /// How its words are set: `.fontSize`, `.lineHeight` and
    /// `.characterSpacing`.
    public static let text = MotionValues(rawValue: 1 << 7)

    /// Everything a view has, which is what a motion is about unless it says
    /// otherwise.
    public static let all = MotionValues(rawValue: ~0)
}

/// How each of a view's values travels: one answer, and the exceptions to it.
///
/// Built by `.motion(_:)` and `.motion(_:_:)` and read by the differ. The plan
/// stays in StateUI; only its resolved `Motion` answers enter host transitions.
/// A view with nothing to say has none of this at all.
struct MotionPlan: Equatable, Sendable {
    /// What every value travels at, where no rule below names it.
    var base: Motion?

    /// The exceptions, in writing order - the LAST one that names a value is
    /// the one that answers for it, which is what a modifier written later
    /// means everywhere else in this library.
    var rules: [(values: MotionValues, motion: Motion)] = []

    /// How one kind of value travels, or nothing where this plan says.
    func motion(for values: MotionValues) -> Motion? {
        for rule in rules.reversed() where !rule.values.isDisjoint(with: values) {
            return rule.motion
        }

        return base
    }

    /// Whether two plans say the same thing. A tuple is not Equatable by
    /// itself, so the rules are compared by hand.
    static func == (one: MotionPlan, other: MotionPlan) -> Bool {
        one.base == other.base
            && one.rules.count == other.rules.count
            && zip(one.rules, other.rules).allSatisfy {
                $0.values == $1.values && $0.motion == $1.motion
            }
    }
}

extension MotionPlan {
    /// What a view is made of, with what was written ON it over the top.
    ///
    /// The author's answer wins - their base replaces the view's own, and their
    /// rules are read first, being the later word. Nil either side is the
    /// common case and costs nothing.
    static func merged(_ made: MotionPlan?, under written: MotionPlan?) -> MotionPlan? {
        guard let written = written else { return made }
        guard let made = made else { return written }

        return MotionPlan(
            base: written.base ?? made.base,
            rules: made.rules + written.rules)
    }
}

/// Which parts of a child's placement travel when a layout puts it somewhere new.
///
/// A host works out where a child sits from native measurement, so placement is
/// not an ordinary `Prop` and cannot carry a property transition. The renderer
/// sends these lanes in `HostLayoutMotion` instead. Written by nobody directly:
/// it is what `.motion(_:_:)` on a layout becomes when the named values are
/// `.place`, `.width` or `.height`.
public struct MotionLanes: OptionSet, Sendable {
    /// The stable lane bits carried by `HostLayoutMotion` and its Wire encoding.
    public let rawValue: UInt8

    /// A set from its members' bits.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// How far along it sits.
    public static let x = MotionLanes(rawValue: 1 << 0)

    /// And how far down.
    public static let y = MotionLanes(rawValue: 1 << 1)

    /// How wide the layout made it.
    public static let width = MotionLanes(rawValue: 1 << 2)

    /// And how tall.
    public static let height = MotionLanes(rawValue: 1 << 3)

    /// Where it sits - both halves of the corner it is placed at.
    public static let place: MotionLanes = [.x, .y]

    /// Everything about a place, which is what a layout says unless it says
    /// otherwise.
    public static let all: MotionLanes = [.x, .y, .width, .height]
}
