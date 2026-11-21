// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The views a tree keeps as they leave: a window's budget of them, and the end of each.
/// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
@_spi(Host) @MainActor public final class KeptExits {
    /// The most views leaving at once a window keeps.
    public static let rootLimit = Transition.keptAtOnce

    /// The most mounted elements a window keeps under the views leaving it.
    public static let mountLimit = 2_048

    /// The longest a view is kept, in milliseconds.
    public static let timeLimit = 2_000.0

    private struct Kept {
        let element: MountedElement
        let window: UInt64
        let mounts: Int
        let latest: Double
    }

    /// The views kept, the oldest first.
    private var kept: [Kept] = []

    /// Told how each kept view's exit ended, once.
    var onEnded: ((MountedElement, PresentationOperation.Result) -> Void)?

    /// How many views are kept.
    public var count: Int { kept.count }

    /// Takes `element` among the kept at `now`, the oldest of its window ending as limited until it fits; false
    /// for one larger than a window's whole budget, which leaves at once.
    func admit(_ element: MountedElement, at now: Double) -> Bool {
        let mounts = element.mountCount
        guard mounts <= Self.mountLimit else { return false }

        let window = element.enclosing(type: .window)?.mount ?? 0
        while let oldest = kept.first(where: { $0.window == window }), !fits(mounts, in: window) {
            oldest.element.endExit(.limited, arranging: true)
            kept.removeAll { $0.element === oldest.element }
        }
        kept.append(Kept(element: element, window: window, mounts: mounts, latest: now + Self.timeLimit))
        return true
    }

    private func fits(_ mounts: Int, in window: UInt64) -> Bool {
        let held = kept.filter { $0.window == window }
        return held.count < Self.rootLimit && held.reduce(mounts) { $0 + $1.mounts } <= Self.mountLimit
    }

    /// `element`'s exit ended as `result`: it is kept no more, and told once.
    func ended(_ element: MountedElement, as result: PresentationOperation.Result) {
        guard kept.contains(where: { $0.element === element }) else { return }

        kept.removeAll { $0.element === element }
        onEnded?(element, result)
    }

    /// Ends as limited every view kept past its time at `now`.
    func expire(now: Double) {
        for late in kept where late.latest <= now { late.element.endExit(.limited, arranging: true) }
    }

    /// Ends every view kept as `result`.
    func endAll(_ result: PresentationOperation.Result) {
        for each in kept { each.element.endExit(result, arranging: true) }
    }
}
