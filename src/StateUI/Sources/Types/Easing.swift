// How an animation spends its time.
//
// MAUI's Easing is a class of static instances rather than an enum, so there is
// no member list to camelCase - but the names are MAUI's all the same, and each
// case's `///` says which static member it stands for. Anything not here is one
// MAUI does not ship.
//
// The numbers are this library's own, as every closed vocabulary's on this wire
// are: declaration order from 0, written out, fixed forever. MAUI is free to
// renumber or reorder anything of its own in any release, and a wire carrying
// its values would then be reinterpreted silently; ours cannot move. The far
// side translates by NAME - a mirror enum carrying these same numbers, each
// member mapped onto the MAUI instance `SwiftFlights.Read` already knows - and
// `WireEnumTests.cs` reads this declaration and compares it against that
// mirror, so the two cannot drift apart without a red test. Appending a case is
// free; inserting or reordering one is not.
//
// An easing is a curve from 0 to 1: given how far through the animation is, it
// says how far through the CHANGE should be. Linear is the straight line, and
// every other one here is worth having only because it is not.

/// The curve an animation follows. MAUI: Easing.
///
/// Given to every flight as `easing:`, defaulting to `.linear`:
///
///     @State private var fade = 1.0
///     …
///     Border { … }.opacity($fade)
///     …
///     try await $fade.animateTo(0.1, length: 400, easing: .cubicOut)
///
/// The names are MAUI's static members, camelCased like every other enum in
/// this library; the numbers are this library's own, as they are everywhere
/// else on this wire. `In` accelerates from a standstill, `Out` decelerates
/// into one, and `InOut` does both - which is why `.cubicOut` is the one to
/// reach for when something arrives on screen, and `.cubicIn` when it leaves.
public enum Easing: Int32, Sendable {
    /// A straight line: the same speed from beginning to end. MAUI: Easing.Linear.
    case linear = 0

    /// Slow at the end, following a sine curve. MAUI: Easing.SinOut.
    case sinOut = 1

    /// Slow at the start, following a sine curve. MAUI: Easing.SinIn.
    case sinIn = 2

    /// Slow at both ends, following a sine curve. MAUI: Easing.SinInOut.
    case sinInOut = 3

    /// Slow at the start, and more pronounced than `.sinIn`. MAUI: Easing.CubicIn.
    case cubicIn = 4

    /// Slow at the end, and more pronounced than `.sinOut`. The usual choice for
    /// something appearing. MAUI: Easing.CubicOut.
    case cubicOut = 5

    /// Slow at both ends, and more pronounced than `.sinInOut`.
    /// MAUI: Easing.CubicInOut.
    case cubicInOut = 6

    /// Overshoots at the end and settles back, twice. MAUI: Easing.BounceOut.
    case bounceOut = 7

    /// Bounces before it sets off. MAUI: Easing.BounceIn.
    case bounceIn = 8

    /// Pulls back before it sets off, the way a spring loads. MAUI: Easing.SpringIn.
    case springIn = 9

    /// Overshoots the target and comes back to it. MAUI: Easing.SpringOut.
    case springOut = 10

    var propValue: PropValue { .enumeration(rawValue) }
}
