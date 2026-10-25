// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A ColorPicker: a `GtkColorDialogButton`, which opens its `GtkColorDialog`; each color the user chooses there is
/// reported as the host layer reports it, and the program's only shown.
/// Design: docs/design/platforms/gtk/controls.md#a-color-picker
@MainActor
final class GTKColorPickerView: GTKView {
    /// What the button does as the user chooses a color.
    var onChosen: ((Color) -> Void)?

    init() {
        super.init { _ in gtk_color_dialog_button_new(gtk_color_dialog_new()) }
        notify("rgba") { _, _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKColorPickerView)?.chosen() }
        }
    }

    /// The dialog the button opens, which the button owns.
    private var dialog: OpaquePointer { gtk_color_dialog_button_get_dialog(widget.opaque) }

    /// The color the button shows, as GTK holds it.
    var rgba: GdkRGBA { gtk_color_dialog_button_get_rgba(widget.opaque).pointee }

    /// Whether the dialog offers opacity.
    var choosesOpacity: Bool { gtk_color_dialog_get_with_alpha(dialog) != 0 }

    /// The color it shows where `write` says the tree changed it, and whether the dialog offers opacity.
    func apply(color: Color, write: Bool, choosesOpacity: Bool) {
        gtk_color_dialog_set_with_alpha(dialog, choosesOpacity ? 1 : 0)
        guard write, let held = color.propValue.fractions else { return }
        var native = GdkRGBA(red: Float(held.red), green: Float(held.green), blue: Float(held.blue), alpha: Float(held.alpha))
        gtk_color_dialog_button_set_rgba(widget.opaque, &native)
    }

    private func chosen() {
        let held = rgba
        onChosen?(ColorChoice.reported(
            (Double(held.red), Double(held.green), Double(held.blue), Double(held.alpha)), choosesOpacity: choosesOpacity))
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
