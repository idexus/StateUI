// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which way a state crosses at an attachment. This library's own.
///
/// Every registration carries one. A placement and a caption's text are
/// `.out`, a feed `.in`; a walked property, a field's text and a value a
/// control reports are `.inOut`.
public enum StateMode: Int32, Sendable {
    /// The host writes it; nothing this side writes reaches the control.
    case `in` = 0

    /// This side writes it; the host reads nothing back.
    case out = 1

    /// Both, which is what almost everything settable and readable is.
    case inOut = 2
}

/// What a registration is about - which of the host's own doors the value goes
/// through. This library's own, numbered in declaration order.
public enum StateKind: Int32, Sendable {
    /// An animated value driving one property of one control.
    case property = 0

    /// A run of placements driving a layout's children.
    case placement = 1

    /// Words written into a text property - out onto a caption, and both ways on a
    /// field the user types into, where the typed words land on the state whole.
    case text = 2

    /// The host writes and this side reads: the frame a layout settled on.
    case feed = 3

    /// A value the host sets as it stands - a flag, a count, a number that never
    /// animates - on its own frames. Both ways where the control reports one: a
    /// switch flipped, a choice made.
    case plain = 4
}

/// One property of one element, driven to a state: which state, which way, which
/// door. The state rather than its number, which is issued later.
struct StateRegistration {
    /// Where the value lives - the image a number is issued against.
    let state: HostStorage

    /// The conversion the state is the derived side of, if it is one.
    var conversion: Conversion? = nil

    /// Which way it crosses.
    let mode: StateMode

    /// Which door the value goes through.
    let kind: StateKind

    /// Which of the view's values this is, which `.inherited` is resolved against.
    let values: MotionValues
}

/// One registration as a host is handed it: the state by its number, which is
/// what a render compares.
struct StateEntry: Equatable {
    /// The state, by the number the host quotes it back by.
    let number: Int32

    /// Which way it crosses.
    let mode: StateMode

    /// Which of the host's doors the value goes through.
    let kind: StateKind
}
