// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A clock a test winds by hand.
@MainActor
final class WoundClock: FrameClock {
    var time = 0.0
    var held = false
    var onFrame: ((Double) -> Void)?
    var now: () -> Double { { [unowned self] in time } }
}

/// A clock no display drives.
@MainActor
final class StillClock: FrameClock {
    let now: () -> Double = { 0 }
    var held = false
    var onFrame: ((Double) -> Void)?
}

/// A native half with nothing native behind it.
@MainActor
final class NoView: NativeElement {
    let presentsView = true
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func leave() {}

    /// How many times the element's children were arranged, and the layouts around it asked to measure again.
    var arranged = 0
    var measuredAgain = 0
    var travels = 0
    func arrangeChildren() { arranged += 1 }
    func invalidateMeasurements() { measuredAgain += 1 }
    func configureLayoutMotion() { travels += 1 }
}

extension HostRuntime {
    /// A runtime on a clock no display drives, whose elements have nothing native behind them.
    static func still() -> HostRuntime {
        HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
    }
}
