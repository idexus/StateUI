// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the user does to the element's view, carried into the runtime by the host layer's rule.
/// Design: docs/design/host/runtime.md#a-users-change
extension UIKitElement {
    /// An event the view raised, with what it carries, to the handler the tree listens with.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let host else { return }
        element.send(event, values, in: host.runtime)
    }

    /// A value the user changed in the view, by the host layer's rule (`reportUserChange`): a radio button its
    /// set's other checks take away shows them taken.
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }
        element.reportUserChange(property, event, value, in: host.runtime) { peer in
            (peer.uiKit.view as? UIKitCheckView)?.setOn(false)
        }
    }

    /// The user moved the scroller from `old` to `new`, as the display's frame saw it.
    func scrolled(from old: Point, to new: Point) {
        guard let host else { return }
        element.reportScrolled(from: old, to: new, in: host.runtime)
    }

    /// Hears the scroller's movement on the display's frames: where it went, and that it came to rest.
    func follow(_ scroll: UIKitScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            guard let self, let scroll else { return }
            host?.runtime.frames.serve(scroll, order: Int64(truncatingIfNeeded: element.mount))
        }
    }
}
#endif
