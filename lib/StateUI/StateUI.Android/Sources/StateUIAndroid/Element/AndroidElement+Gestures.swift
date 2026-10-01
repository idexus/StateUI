// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The user's input to the view, heard by the host layer's rule (`MountedElement.hearing`, `hear`).
/// Design: docs/design/platforms/android/controls.md#gestures
extension AndroidElement {
    /// A tap is the view's click where one makes it; runs of taps, a press dragged, a pinch and the pointer are the
    /// listener's.
    func configureGestures() {
        guard let view else { return }
        let hearing = element.hearing
        let count = max(1, Int(value(.tapCount)?.number ?? 1))
        let heard: (HeardInput) -> Void = { [weak self] heard in
            guard let self, let host else { return }
            element.hear(heard, in: host.runtime)
        }
        view.setTapped(hearing.contains(.taps) && count == 1 ? { heard(.tap(run: 1)) } : nil)
        view.hear(hearing, countsTaps: count > 1, heard)
    }
}
