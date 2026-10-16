// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The hands over layouts a frame has business with: the wheels open, let go by the frames that find them still - a
/// wheel tells no lift - and the hands' reports since the last frame, said at its start.
/// Design: docs/design/host/runtime.md#the-hand-over-a-layout
@_spi(Host) @MainActor public final class HandPace {
    /// The elements whose wheel is open or whose hand's reports wait, by their mount.
    private var open: [UInt64: WeakElement] = [:]

    /// What a wheel opening asks of the clock: frames, until it is let go.
    var onOpen: (() -> Void)?

    /// Whether any wheel is open or any hand's reports wait.
    public var isOpen: Bool { !open.isEmpty }

    /// No wheel open.
    public init() {}

    /// `element`'s wheel is open or its hand said something: the frames pace it until it is let go and said.
    func opened(_ element: MountedElement) {
        open[element.mount] = WeakElement(element)
        onOpen?()
    }

    /// A frame at `now`: every open wheel found still long enough is let go, and every hand's reports are said, in
    /// mount order.
    public func pace(now: Double, in runtime: HostRuntime) {
        for mount in open.keys.sorted() {
            guard let element = open[mount]?.element else {
                open[mount] = nil
                continue
            }

            element.paced(now: now, in: runtime)
            if !element.handReading.wantsFrames, element.handOutbox.isEmpty { open[mount] = nil }
        }
    }

    /// An element held weakly: a wheel never keeps a view the tree let go.
    private struct WeakElement {
        weak var element: MountedElement?

        init(_ element: MountedElement) { self.element = element }
    }
}
