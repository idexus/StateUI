// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// A picker as GTK shows it - a drop-down, a row of linked toggle buttons or a column of radio buttons - written
/// and heard alike.
/// Design: docs/design/views/controls.md#a-pickers-presentation
@MainActor
protocol GTKChoosing: GTKView {
    /// What the picker does when the user chooses, handed the chosen choice's place.
    var onChosen: ((Int) -> Void)? { get set }

    /// The chosen choice's place; nil while none is.
    var chosen: Int? { get }

    /// The choices offered, as GTK holds them.
    var offered: [String] { get }

    /// The choices, then the one chosen - written only where the tree changed it or the choices changed.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool)

    /// The style sheet's class the words take their look from.
    func setWordsClass(_ name: String?)

    /// Chooses the choice at `place` as the user does.
    func choose(_ place: Int)
}

extension GTKPickerView: GTKChoosing {
    var offered: [String] {
        guard let model = gtk_drop_down_get_model(widget.opaque) else { return [] }
        return (0..<g_list_model_get_n_items(model)).map { String(cString: gtk_string_list_get_string(model, $0)) }
    }

    func choose(_ place: Int) {
        gtk_drop_down_set_selected(widget.opaque, guint(place))
    }
}
