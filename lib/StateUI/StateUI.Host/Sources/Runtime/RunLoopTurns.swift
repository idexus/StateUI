// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(Darwin)
import CoreFoundation
@_spi(Host) import StateUI

/// The turn an Apple host takes after each pass of the main run loop - before it sleeps, or as a run of it returns -
/// where every write, act and resumed task of the pass has landed; no thread of its own rings for it.
/// Design: docs/design/host/runtime.md#the-turn-on-apple
@_spi(Host) @MainActor public final class RunLoopTurns {
    private var observer: CFRunLoopObserver?

    /// Turns `pump` after every pass of the main run loop, in every common mode, from now until `stop()`.
    public init(_ pump: Pump) {
        let observer = CFRunLoopObserverCreateWithHandler(
            nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue, true, Self.order
        ) { [weak pump] _, _ in
            MainActor.assumeIsolated { pump?.turnIfWanted() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    /// Ahead of Core Animation's commit, which shows what the turn changed in the same pass.
    private static let order: CFIndex = 1_000_000

    /// Takes no more turns.
    public func stop() {
        if let observer { CFRunLoopObserverInvalidate(observer) }
        observer = nil
    }

    isolated deinit {
        stop()
    }
}
#endif
