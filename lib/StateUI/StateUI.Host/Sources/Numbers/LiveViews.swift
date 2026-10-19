// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A host's views by number, held weakly: what a toolkit's callback names a view by - a number crossing C where
/// an object cannot - and what a test counts to see every view let go.
/// Design: docs/design/host/tree.md#held-by-number
@_spi(Host) @MainActor public final class LiveViews<View: AnyObject> {
    private let live = Numbered<Held>()

    private struct Held {
        weak var view: View?
    }

    /// No view yet.
    public init() {}

    /// The next number, for a view being made.
    public func reserve() -> Int64 {
        live.reserve()
    }

    /// Holds `view` under `number`, weakly.
    public func hold(_ view: View, as number: Int64) {
        live.hold(Held(view: view), as: number)
    }

    /// Lets go of the view under `number`.
    public func release(_ number: Int64) {
        live.release(number)
    }

    /// The live view under `number`; nil once it has left.
    public func find(_ number: Int64) -> View? {
        live.find(number)?.view
    }

    /// How many views are held.
    public var count: Int { live.count }
}
