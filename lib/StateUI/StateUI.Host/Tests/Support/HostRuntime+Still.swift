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
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        HostChildMeasured(size: .zero, firstBaseline: nil)
    }
    let presentsView: Bool

    init(presentsView: Bool = true) {
        self.presentsView = presentsView
    }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    /// Whether the view takes its properties' movements; a test that moves one says so.
    var animatesProperties = false
    func animates(_ property: Prop) -> Bool { animatesProperties }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}

    /// The properties the element was asked to present, a frame's or an entry's at a time.
    var presented: [Set<Prop>] = []
    func presentFrame(_ changed: Set<Prop>) { presented.append(changed) }

    /// How many times the element was told it is the application's no more.
    var deactivated = 0
    func deactivate() { deactivated += 1 }

    /// How many times the element was told nothing of it is drawn any more.
    var released = 0
    func releasePresentation() { released += 1 }

    /// Whether its view keeps a child that left.
    var keepsExits = false

    /// Where its view stands, as a frame report's numbers; nil while it stands nowhere. How many times it was asked.
    var frame: [Double]?
    var frameReads = 0
    func frameNumbers() -> [Double]? {
        frameReads += 1
        return frame
    }

    /// How many times the element's children were arranged, and the layouts around it asked to measure again.
    var arranged = 0
    var measuredAgain = 0
    var travels = 0
    func arrangeChildren() { arranged += 1 }
    /// How many times the element's children were drawn again in their layout's order.
    var ordered = 0
    func orderChildren() { ordered += 1 }
    func invalidateMeasurements() { measuredAgain += 1 }
    func configureLayoutMotion() { travels += 1 }
}

extension HostRuntime {
    /// A runtime on a clock no display drives, whose elements have nothing native behind them.
    static func still() -> HostRuntime {
        HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
    }
}
