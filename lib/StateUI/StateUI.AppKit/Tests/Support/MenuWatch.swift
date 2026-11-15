// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A menu as it opens: its entries read, and closed at once as the run loop tracks it.
@MainActor
final class MenuWatch: NSObject {
    private(set) var opened: [String] = []

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(began(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
    }

    @objc private func began(_ note: Notification) {
        guard let menu = note.object as? NSMenu else { return }
        opened = menu.items.map(\.title)
        menu.perform(#selector(NSMenu.cancelTracking), with: nil, afterDelay: 0, inModes: [.eventTracking])
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
    }
}

#endif
