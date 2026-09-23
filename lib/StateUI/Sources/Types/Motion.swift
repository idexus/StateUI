// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How a value animates when it changes: one vocabulary for the application, an
// element, a state and a single write.
// Design: docs/design/types/motion.md#one-vocabulary-in-four-places

/// How a value animates when it changes.
///
/// A change animates by default - assign a state and the control animates to
/// the new value - and a motion says how:
///
///     VStack { … }.motion(.spring(response: 260))
///
///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
///
/// `.none` applies a change at once. `.custom` hands the animation to an
/// engine of your own. `.eased` and `.spring` name a timing law and its
/// numbers.
///
/// Design: docs/design/types/motion.md#two-laws
public struct Motion: Equatable, Sendable {
    /// Which timing law a motion follows.
    public enum Law: Int32, Sendable {
        /// A stated duration on a stated curve.
        case eased = 0

        /// A mass on a spring - no duration, only a response.
        case spring = 1
    }

    /// The timing law this motion follows.
    public let law: Law

    /// Milliseconds: how long an eased motion takes, or a spring's response.
    public let millis: UInt32

    /// The curve an eased motion follows.
    public let curve: Easing

    /// A spring's damping; 0 for an eased motion.
    public let factor: Double

    /// Whether this motion is the one its element resolves to rather than one
    /// of its own.
    public let isInherited: Bool

    /// Whether an application engine animates the value instead of the host;
    /// see `custom`.
    public let isCustom: Bool

    /// The motion the element resolves to: its own, else the application's,
    /// else `standard`.
    ///
    /// What a write means when it names no motion, so a plain assignment and
    /// `move(to:)` agree about the motion and differ only in being awaited.
    public static let inherited = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: true, isCustom: false)

    /// No animation: the change is applied at once.
    public static let none = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false, isCustom: false)

    /// The animation is yours: a write moves only the destination, the host
    /// animates nothing, and an engine of your own writes where the value is
    /// and how fast it is going, frame by frame, reading the destination back.
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
    /// Unlike `.none`, a write changes only where the value is going; where it
    /// is stays put until the engine moves it. Declare it on the state, since
    /// which side animates a state is fixed when the state first reaches the
    /// host.
    ///
    /// Design: docs/design/types/motion.md#custom-animates-in-an-engine
    public static let custom = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false, isCustom: true)

    /// An animation of a stated duration on a stated curve.
    ///
    ///     .motion(.eased(400, .cubicOut))
    ///
    /// It takes the stated time whatever the distance: right for something
    /// whose distance is known, such as a fade, a page sliding in, or a card
    /// turning over.
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
    /// It has no duration: a spring settles when it is done, and one whose
    /// destination changes mid-animation carries on from the speed it had.
    /// That makes it right for anything the user can interrupt - a card being
    /// dragged, a value still being chosen.
    ///
    /// - Parameters:
    ///   - response: how quickly it answers, in milliseconds. Smaller is
    ///     snappier.
    ///   - damping: 1 comes to rest without overshooting; below 1 overshoots
    ///     and oscillates, which is rarely what a user expects.
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

    /// Whether this motion animates nothing - the value simply arrives.
    var isNothing: Bool {
        !isInherited && !isCustom && law == .eased && millis == 0
    }

    /// This motion, or `fallback` where this is the inherited one.
    func resolved(against fallback: Motion) -> Motion {
        isInherited ? fallback : self
    }

    /// The default motion: 200 milliseconds on `.cubicOut`, for ordinary
    /// changes and a scroller's landing.
    public static let standard = Motion.eased(200, .cubicOut)
}

/// Which groups of a view's values a motion applies to.
///
/// A motion written on a view applies to all of them unless it names some:
///
///     VStack { … }
///         .motion(.spring(response: 240))
///         .motion(.none, .size)
///
/// The stack's children move to their new places on a spring and take their
/// new size at once. A property in none of the groups follows the plain
/// `.motion(_:)` and `.all`. Visual states, showing and hiding, and a
/// child's placement follow the plain `.motion(_:)` too, and a rule naming
/// `.place`, `.width` or `.height` can snap those parts of a placement alone.
///
/// Design: docs/design/types/motion.md#groups-of-values
public struct MotionValues: OptionSet, Sendable {
    /// The members this set holds.
    public let rawValue: Int

    /// A set from its members' bits, which is what an OptionSet is made of.
    ///
    /// - Parameter rawValue: the bits.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// How see-through the view is: `.opacity`.
    public static let opacity = MotionValues(rawValue: 1 << 0)

    /// Every colour it wears - a background, a text colour, a track, a thumb -
    /// known from the value itself.
    public static let colour = MotionValues(rawValue: 1 << 1)

    /// How wide it is: `.width`, `.minimumWidth`, `.maximumWidth`, and on a
    /// layout the widths it gives its children.
    public static let width = MotionValues(rawValue: 1 << 2)

    /// How tall it is: `.height`, `.minimumHeight`, `.maximumHeight`, and on a
    /// layout the heights it gives its children.
    public static let height = MotionValues(rawValue: 1 << 3)

    /// Both dimensions, plus the lengths its own shape is drawn with:
    /// `.cornerRadius`, `.strokeWidth` and `.borderWidth`.
    public static let size: MotionValues = [.width, .height]

    /// Where it sits: the place its layout gives it, and `.translationX` or
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

    /// Everything a view has, which is what a motion applies to unless it says
    /// otherwise.
    public static let all = MotionValues(rawValue: ~0)
}

/// How each of a view's values animates: one answer, and the exceptions to it.
/// Built by `.motion(_:)` and `.motion(_:_:)`; read by the differ.
/// Design: docs/design/types/motion.md#a-plan-per-view
struct MotionPlan: Equatable, Sendable {
    /// What every value animates with, where no rule names it.
    var base: Motion?

    /// The exceptions, in writing order; the last one naming a value wins.
    var rules: [(values: MotionValues, motion: Motion)] = []

    /// How one kind of value animates, or nothing where this plan says.
    func motion(for values: MotionValues) -> Motion? {
        for rule in rules.reversed() where !rule.values.isDisjoint(with: values) {
            return rule.motion
        }

        return base
    }

    /// Compares the rules by hand: a tuple is not Equatable.
    static func == (one: MotionPlan, other: MotionPlan) -> Bool {
        one.base == other.base
            && one.rules.count == other.rules.count
            && zip(one.rules, other.rules).allSatisfy {
                $0.values == $1.values && $0.motion == $1.motion
            }
    }
}

extension MotionPlan {
    /// A view's own plan with the plan written on it over the top: the written
    /// base wins, and the written rules come later, so they win too.
    static func merged(_ made: MotionPlan?, under written: MotionPlan?) -> MotionPlan? {
        guard let written = written else { return made }
        guard let made = made else { return written }

        return MotionPlan(
            base: written.base ?? made.base,
            rules: made.rules + written.rules)
    }
}

/// Which parts of a child's placement animate when a layout moves it.
///
/// Not written directly: `.motion(_:_:)` on a layout naming `.place`, `.width`
/// or `.height` becomes this, carried in `HostLayoutMotion`.
///
/// Design: docs/design/types/motion.md#layout-lanes
public struct MotionLanes: OptionSet, Sendable {
    /// The lane bits carried by `HostLayoutMotion` and its Wire encoding.
    public let rawValue: UInt8

    /// A set from its members' bits.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// How far along it sits.
    public static let x = MotionLanes(rawValue: 1 << 0)

    /// How far down it sits.
    public static let y = MotionLanes(rawValue: 1 << 1)

    /// How wide the layout made it.
    public static let width = MotionLanes(rawValue: 1 << 2)

    /// How tall the layout made it.
    public static let height = MotionLanes(rawValue: 1 << 3)

    /// Where it sits - both halves of the corner it is placed at.
    public static let place: MotionLanes = [.x, .y]

    /// Everything about a place, which is what a layout says unless it says
    /// otherwise.
    public static let all: MotionLanes = [.x, .y, .width, .height]
}
