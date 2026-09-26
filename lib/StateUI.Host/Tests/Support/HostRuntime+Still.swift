// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

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
    func willApply() {}
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) -> FrameImpact { .none }
    func arrangeChildren() {}
    func leave() {}
}

extension HostRuntime {
    /// A runtime on a clock no display drives, whose elements have nothing native behind them.
    static func still() -> HostRuntime {
        HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
    }
}
