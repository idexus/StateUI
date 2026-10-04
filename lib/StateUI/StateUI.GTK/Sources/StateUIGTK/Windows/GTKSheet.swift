// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A page a window's modal stack presents, shown as libadwaita's `AdwDialog` over the window: a page in a frame of
/// its own - whose header bar holds the dialog's close button - or an arrangement whose pages carry theirs. The
/// user's close tells `onClosedByUser`; the program's tells nothing.
/// Design: docs/design/platforms/gtk/pages.md#sheets
@MainActor
final class GTKSheet {
    /// The dialog, held until the sheet goes.
    let dialog: UnsafeMutablePointer<AdwDialog>

    /// The view the sheet shows.
    let page: GTKView

    /// The frame a page stands in on the sheet; nil for an arrangement.
    let frame: GTKPageFrame?

    /// What the sheet does when the user closes it - Escape, its close button.
    var onClosedByUser: (() -> Void)?

    /// The number its dialog's signal carries, one across the process.
    private let number: Int64
    private static var nextNumber: Int64 = 1
    private static var shown: [Int64: GTKSheet] = [:]

    /// Whether the dialog has closed, or is closing as the program closes it.
    private var isClosed = false

    /// The size a sheet asks for, which libadwaita fits to the window - a sheet from the bottom where it is narrow.
    private static let size = (width: Int32(560), height: Int32(480))

    init(page: GTKView, framed: Bool) {
        self.page = page
        frame = framed ? GTKPageFrame(page: page) : nil
        dialog = adw_dialog_new()!
        g_object_ref_sink(UnsafeMutableRawPointer(dialog))
        number = Self.nextNumber
        Self.nextNumber += 1
        adw_dialog_set_content_width(dialog, Self.size.width)
        adw_dialog_set_content_height(dialog, Self.size.height)
        adw_dialog_set_child(dialog, frame?.widget ?? page.widget)
        connectSignal(UnsafeMutableRawPointer(dialog), "closed", number: number) { _, data in
            MainActor.assumeIsolated { GTKSheet.shown.removeValue(forKey: viewNumber(data))?.closedByDialog() }
        }
    }

    isolated deinit {
        g_signal_handlers_disconnect_matched(
            UnsafeMutableRawPointer(dialog), STATEUI_SIGNAL_MATCH_DATA, 0, 0, nil, nil,
            UnsafeMutableRawPointer(bitPattern: Int(number)))
        adw_dialog_set_child(dialog, nil)
        g_object_unref(UnsafeMutableRawPointer(dialog))
    }

    /// Shows the sheet over `window`, over the sheets shown there before it.
    func present(over window: GTKWindow) {
        Self.shown[number] = self
        adw_dialog_present(dialog, window.widget)
    }

    /// The sheet's title, which the dialog says to assistive technology and which a page's frame shows.
    func setTitle(_ title: String) {
        adw_dialog_set_title(dialog, title)
    }

    /// Closes the sheet as the program does: nobody hears it as the user's.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        Self.shown[number] = nil
        adw_dialog_force_close(dialog)
    }

    /// The dialog closed: the user's close, where the program did not close it.
    private func closedByDialog() {
        guard !isClosed else { return }
        isClosed = true
        onClosedByUser?()
    }
}
