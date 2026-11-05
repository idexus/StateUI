// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's press recognizer: a press held as long as the view's hold waits - AppKit's own time where it says none -
/// told once it is. Recognized, it keeps the view's click and drag recognizers from the press.
/// Design: docs/design/platforms/appkit/input.md#a-press-held
@MainActor
final class AppKitHoldRecognizer: NSPressGestureRecognizer {
    private let hearing: AppKitHearing

    /// AppKit's own time, which a view saying none waits.
    private static let platformTime = NSPressGestureRecognizer().minimumPressDuration

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitHoldRecognizer is created in code")
    }

    /// Waits `milliseconds` for a hold, or AppKit's own time for nil.
    func wait(_ milliseconds: Double?) {
        minimumPressDuration = milliseconds.map { $0 / 1000 } ?? Self.platformTime
    }

    @objc private func recognized(_ sender: NSPressGestureRecognizer) {
        recognized(sender.state, at: sender.location(in: nil))
    }

    /// AppKit's press at `state`, at `point` of the window: held once it begins where a point lands in the view -
    /// none where the view is flattened by its drawing.
    func recognized(_ state: NSGestureRecognizer.State, at point: NSPoint) {
        guard state == .began, let view, view.drawnPoint(fromWindow: point) != nil else { return }
        held()
    }

    /// The press was held.
    func held() {
        hearing(.hold)
    }
}

#endif
