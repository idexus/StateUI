// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's click recognizer for a view counting a run of taps, each click told with its place in a quick run of
/// clicks: how many clicks in a run make a tap is the host layer's to count. A single tap is the press's
/// (`AppKitPressRecognizer`).
/// Design: docs/design/platforms/appkit/input.md#what-the-user-does
@MainActor
final class AppKitTapRecognizer: NSClickGestureRecognizer {
    private let hearing: AppKitHearing

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTapRecognizer is created in code")
    }

    /// Whether the view counts a run of taps.
    var countsRuns = false

    @objc private func recognized(_ sender: NSClickGestureRecognizer) {
        clicked(run: NSApp.currentEvent.map { max(1, $0.clickCount) } ?? 1)
    }

    /// A click, the `run`th of a quick run, where the view counts runs.
    func clicked(run: Int) {
        if countsRuns { hearing(.tap(run: run)) }
    }
}

#endif
