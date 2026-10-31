// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// A page a view presents, shown as libadwaita's `AdwDialog` over the window: a page alone - a sheet has no bar of
/// its own - or an arrangement whose pages carry theirs, a stack's header bars holding the dialog's close button; a
/// tabbed view in a frame holding its switcher. The user's close tells `onClosedByUser`; the program's tells nothing.
/// Design: docs/design/platforms/gtk/pages.md#sheets
@MainActor
final class GTKSheet {
    /// The dialog, held until the sheet goes.
    let dialog: UnsafeMutablePointer<AdwDialog>

    /// The view the sheet shows.
    let page: GTKView

    /// The frame a tabbed view stands in on the sheet; nil for a page or another arrangement.
    let frame: GTKPageFrame?

    /// What the sheet does when the user closes it - Escape, its close button.
    var onClosedByUser: (() -> Void)?

    /// The number its dialog's signal carries, one across the process.
    private let number: Int64
    private static let shown = Numbered<GTKSheet>()

    /// Whether the dialog has closed, or is closing as the program closes it.
    private var isClosed = false

    /// The room a sheet stands in on a wide window (`SheetSize`): at least 320 x 180, 560 x 480 for a page asking
    /// none, at most the window less 24 pixels a side; libadwaita fits it to the window - from the bottom where it is
    /// narrow.
    static func room(in window: GTKWindow) -> SheetRoom {
        // A window not laid out yet stands at the size it asks for.
        var (width, height) = (gtk_widget_get_width(window.widget), gtk_widget_get_height(window.widget))
        if width <= 0 || height <= 0 { gtk_window_get_default_size(window.widget.of(GtkWindow.self), &width, &height) }
        return SheetRoom(
            least: LayoutSize(width: 320, height: 180), standard: LayoutSize(width: 560, height: 480),
            most: LayoutSize(width: Double(width) - 48, height: Double(height) - 48))
    }

    /// Asks the dialog for `size`, written only where it differs.
    func stand(at size: LayoutSize) {
        let (width, height) = (Int32(size.width.rounded()), Int32(size.height.rounded()))
        if adw_dialog_get_content_width(dialog) != width { adw_dialog_set_content_width(dialog, width) }
        if adw_dialog_get_content_height(dialog) != height { adw_dialog_set_content_height(dialog, height) }
    }

    init(page: GTKView, framed: Bool) {
        self.page = page
        frame = framed ? GTKPageFrame(page: page) : nil
        dialog = adw_dialog_new()!
        g_object_ref_sink(UnsafeMutableRawPointer(dialog))
        number = Self.shown.reserve()
        adw_dialog_set_child(dialog, frame?.widget ?? page.widget)
        connectSignal(UnsafeMutableRawPointer(dialog), "closed", number: number) { _, data in
            MainActor.assumeIsolated { GTKSheet.shown.take(viewNumber(data))?.closedByDialog() }
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
        Self.shown.hold(self, as: number)
        adw_dialog_present(dialog, window.widget)
    }

    /// The class standing the dialog on its window's background; nil on libadwaita's own.
    private var groundClass: String?

    /// Stands the sheet on `ground` - its window's background - laid over libadwaita's own surface, which stands
    /// alone where it is empty. GTK blurs nothing inside a window, so a blur stands as its color.
    /// Design: docs/design/platforms/gtk/pages.md#sheets
    func stand(on ground: HostMaterial) {
        let wanted = GTKBrush(ground.painted).firstColor.map(GTKStyleSheet.sheetGround)
        guard wanted != groundClass else { return }
        let widget = dialog.of(GtkWidget.self)
        if let groundClass { gtk_widget_remove_css_class(widget, groundClass) }
        if let wanted { gtk_widget_add_css_class(widget, wanted) }
        groundClass = wanted
    }

    /// The sheet's title, which the dialog says to assistive technology and which a page's frame shows.
    func setTitle(_ title: String) {
        adw_dialog_set_title(dialog, title)
    }

    /// Closes the sheet as the program does: nobody hears it as the user's.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        Self.shown.release(number)
        adw_dialog_force_close(dialog)
    }

    /// The dialog closed: the user's close, where the program did not close it.
    private func closedByDialog() {
        guard !isClosed else { return }
        isClosed = true
        onClosedByUser?()
    }
}
