// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A popover's view: what it holds, standing in Android's popup window by its anchor while it shows - the relay's
/// `StateUIPopover`; `onClosed` hears the user take it away.
/// Design: docs/design/platforms/android/pages.md#a-popover
@MainActor
final class AndroidPopoverView: AndroidSingleChildView {
    var onClosed: (() -> Void)?

    /// The popup window holding the view, once it was first shown.
    private(set) var window: JavaObject?

    /// Whether the popup window shows.
    var windowShows: Bool {
        window.map { Java.callBool($0.reference, JavaAPI.isPopoverShowing) } ?? false
    }

    /// Shows the popover by `anchor`.
    func show(by anchor: AndroidView) {
        let window = self.window ?? Java.new(JavaAPI.popover, JavaAPI.newPopover, .object(reference), .long(number))
        self.window = window
        Java.call(window.reference, JavaAPI.showPopover, .object(anchor.outermost))
    }

    func close() {
        window.map { Java.call($0.reference, JavaAPI.closePopover) }
    }

    override func closed() {
        onClosed?()
    }

    override func detach() {
        close()
        onClosed = nil
        super.detach()
    }
}
