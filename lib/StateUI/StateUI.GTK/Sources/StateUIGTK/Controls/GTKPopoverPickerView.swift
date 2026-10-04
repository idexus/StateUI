// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// A picker whose button shows its day or its time and opens a popover holding its face - its calendar, its clock:
/// a `GtkMenuButton`, its words a label of its own beside its arrow. Only the user's opening and closing are heard
/// (`PickerOpening`).
/// Design: docs/design/platforms/gtk/controls.md#a-day-and-a-time
@MainActor
class GTKPopoverPickerView: GTKView {
    /// What the picker does as the user opens its face and closes it.
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The words the button shows.
    let label: GTKWidget

    /// The popover, holding the face.
    let popover: GTKWidget

    private var opening = PickerOpening()
    private var wordsClass: String?

    /// The picker opening `face`.
    init(face: GTKWidget) {
        label = gtk_label_new(nil)!
        popover = gtk_popover_new()!
        super.init { _ in gtk_menu_button_new() }
        gtk_menu_button_set_child(widget.opaque, label)
        gtk_menu_button_set_always_show_arrow(widget.opaque, 1)
        gtk_popover_set_child(popover.of(GtkPopover.self), face)
        gtk_menu_button_set_popover(widget.opaque, popover)
        connectNotify(UnsafeMutableRawPointer(popover), "visible", number: number) { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKPopoverPickerView)?.shownOrHidden() }
        }
    }

    /// Whether the face shows.
    var isOpen: Bool { gtk_widget_get_visible(popover) != 0 }

    /// Opens or closes the face; neither is the user's, so neither is heard.
    func setOpen(_ open: Bool) {
        guard opening.programAsks(open: open, shown: isOpen) else { return }
        if open { gtk_menu_button_popup(widget.opaque) } else { gtk_menu_button_popdown(widget.opaque) }
    }

    /// The words the button shows.
    func setWords(_ words: String) {
        gtk_label_set_text(label.opaque, words)
    }

    /// The style sheet's class the button's words take their look from.
    func setWordsClass(_ name: String?) {
        swapClass(&wordsClass, to: name, on: label)
        invalidateMeasure()
    }

    private func shownOrHidden() {
        let open = isOpen
        guard opening.heard(open: open) else { return }
        if open { onOpened?() } else { onClosed?() }
    }

    override func detach() {
        super.detach()
        (onOpened, onClosed) = (nil, nil)
    }
}
