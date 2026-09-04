// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// HOW A VALUE MOVES WHEN IT CHANGES.
//
// The tree describes where the interface is GOING; the host's engine is how the
// screen catches up. This is the whole of what an author says about that
// catching up - one vocabulary, used in three places and meaning the same thing
// in all of them:
//
//     Application.motion            what everything moves at, by default
//     .motion(.none)                what THIS element does instead
//     $fade.animateTo(0.1, .spring())   what THIS write does instead
//
// Nothing about a motion rides the wire except the resolved numbers: a length
// and a curve, or a spring's two. The frames themselves are the host's and
// never cross - that is not the wire's work.
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

/// How a value moves when it changes. This library's own.
///
/// A change is a MOTION by default - assign a state and the control travels
/// there - and this is what says how:
///
///     VStack { … }.motion(.spring(response: 260))
///
///     try await $fade.animateTo(0.1, .eased(400, .cubicOut))
///
/// `.none` is how something snaps: the value is written and the screen is
/// already showing it. Every other case names a law and the numbers it needs.
public struct Motion: Equatable, Sendable {
    /// Which law a movement travels under, as the wire carries it.
    ///
    /// The numbers are this library's own, as every closed vocabulary's on this
    /// wire are: declaration order from 0, fixed forever. See Types/Easing.swift
    /// for why nothing here is ever a platform's own numbering.
    enum Law: Int32, Sendable {
        /// A stated length on a stated curve.
        case eased = 0

        /// A mass on a spring - no length, only a response.
        case spring = 1
    }

    /// The law this motion travels under.
    let law: Law

    /// Milliseconds: how long an eased motion takes, or a spring's response.
    let millis: UInt32

    /// The curve an eased motion follows.
    let curve: Easing

    /// A spring's damping. Nought where the law has no use for one.
    let factor: Double

    /// Whether this motion is the one its element resolves to rather than one
    /// of its own.
    let isInherited: Bool

    /// Whatever the element this is written on resolves to - the element's own
    /// motion, or the application's, or this library's.
    ///
    /// What a write means when it says nothing about how to travel, which is
    /// what makes `.animateTo(x)` and a plain assignment agree about the
    /// motion and differ only in being awaited.
    public static let inherited = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: true)

    /// No motion: the value is written and the screen is already showing it.
    ///
    /// The escape from everything here, and it costs nothing at all - a value
    /// that snaps is a value with no motion beside it on the wire.
    public static let none = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false)

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
            isInherited: false)
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
            isInherited: false)
    }

    /// Whether this motion moves nothing - the value simply arrives.
    var isNothing: Bool {
        !isInherited && law == .eased && millis == 0
    }

    /// This motion, or `fallback` where this is the inherited one.
    func resolved(against fallback: Motion) -> Motion {
        isInherited ? fallback : self
    }

    /// What everything moves at unless something says otherwise.
    ///
    /// Two hundred milliseconds is the one soft-stop this library already has -
    /// the landing every scroller makes - so there is ONE number for the whole
    /// system rather than a second one to explain beside it.
    public static let standard = Motion.eased(200, .cubicOut)
}

/// WHICH of a view's values a motion is about. This library's own.
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
/// reader thinks about what they are watching. Each one says exactly which MAUI
/// properties it covers. A property in none of them is reached by the plain
/// form and by `.all`, which is what almost every motion there is says.
///
/// WHAT A RULE STEERS is the properties the tree describes. The few things the
/// HOST decides for itself - where a layout puts its children, what a visual
/// state changes, and whether showing and hiding crosses - follow the plain
/// `.motion(_:)`, since there is no property of theirs to name. The one
/// exception is a PLACE: `.place`, `.width` and `.height` are its own parts, so
/// a rule naming them holds that part of a child's place still.
public struct MotionValues: OptionSet, Sendable {
    /// The members this set holds.
    public let rawValue: Int

    /// A set from its members' bits, which is what an OptionSet is made of.
    ///
    /// - Parameter rawValue: the bits.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// How see-through the view is. MAUI: VisualElement.Opacity.
    public static let opacity = MotionValues(rawValue: 1 << 0)

    /// Every colour it wears - a background, a text colour, a track, a thumb.
    ///
    /// Read off the VALUE rather than from a list of property names, so a
    /// colour added to this library later is in here the day it arrives.
    public static let colour = MotionValues(rawValue: 1 << 1)

    /// How wide it is, and how wide a layout made it. MAUI:
    /// WidthRequest, MinimumWidthRequest, MaximumWidthRequest.
    public static let width = MotionValues(rawValue: 1 << 2)

    /// How tall it is, and how tall a layout made it. MAUI:
    /// HeightRequest, MinimumHeightRequest, MaximumHeightRequest.
    public static let height = MotionValues(rawValue: 1 << 3)

    /// Both sides of how big it is, and the lengths its own shape is drawn
    /// with. MAUI: the width and height above, CornerRadius, StrokeThickness,
    /// BorderWidth, RadiusX and RadiusY.
    public static let size: MotionValues = [.width, .height]

    /// Where it SITS: what a layout does with it, and what it was moved by.
    /// MAUI: TranslationX and TranslationY, and the arrangement itself, which
    /// is not a property at all.
    public static let place = MotionValues(rawValue: 1 << 4)

    /// How it is turned and how big it is DRAWN, which is not how big it is.
    /// MAUI: Scale, ScaleX, ScaleY, Rotation, RotationX, RotationY, AnchorX,
    /// AnchorY.
    public static let transform = MotionValues(rawValue: 1 << 5)

    /// The room it keeps around and inside itself. MAUI: Padding, Margin,
    /// Spacing, RowSpacing, ColumnSpacing.
    public static let spacing = MotionValues(rawValue: 1 << 6)

    /// How its words are set. MAUI: FontSize, LineHeight, CharacterSpacing.
    public static let text = MotionValues(rawValue: 1 << 7)

    /// Everything a view has, which is what a motion is about unless it says
    /// otherwise.
    public static let all = MotionValues(rawValue: ~0)
}

/// How each of a view's values travels: one answer, and the exceptions to it.
///
/// Built by `.motion(_:)` and `.motion(_:_:)`, read by the differ, and never
/// sent - what rides the wire is the resolved numbers beside each property. A
/// view with nothing to say has none of this at all.
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

/// Which parts of a child's PLACE travel when a layout puts it somewhere new.
/// This library's own.
///
/// Where a child sits is worked out on the host, from what it measured, so it
/// is not a property and cannot carry a motion beside it - this is what crosses
/// instead. Written by nobody directly: it is what `.motion(_:_:)` on a layout
/// comes to when the values it names are `.place`, `.width` or `.height`.
struct MotionLanes: OptionSet, Sendable {
    /// The lanes this set holds, which is what rides the wire.
    let rawValue: UInt8

    /// A set from its members' bits.
    init(rawValue: UInt8) { self.rawValue = rawValue }

    /// How far along it sits.
    static let x = MotionLanes(rawValue: 1 << 0)

    /// And how far down.
    static let y = MotionLanes(rawValue: 1 << 1)

    /// How wide the layout made it.
    static let width = MotionLanes(rawValue: 1 << 2)

    /// And how tall.
    static let height = MotionLanes(rawValue: 1 << 3)

    /// Where it sits - both halves of the corner it is placed at.
    static let place: MotionLanes = [.x, .y]

    /// Everything about a place, which is what a layout says unless it says
    /// otherwise.
    static let all: MotionLanes = [.x, .y, .width, .height]
}
