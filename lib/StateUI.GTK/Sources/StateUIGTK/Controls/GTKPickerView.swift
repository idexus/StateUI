// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A Picker: a `GtkDropDown` over a list of its choices' words, the chosen one shown on its button.
/// Design: docs/design/platforms/gtk/controls.md#a-picker
@MainActor
final class GTKPickerView: GTKView {
    /// What the picker does when the user chooses, handed the chosen choice's place.
    var onChosen: ((Int) -> Void)?

    /// The choices, as the list holds them.
    private(set) var choices: [String] = []

    init() {
        super.init { _ in gtk_drop_down_new(nil, nil) }
        notify("selected") { _, _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKPickerView, let chosen = view.chosen else { return }
                view.onChosen?(chosen)
            }
        }
    }

    /// The chosen choice's place; nil while none is.
    var chosen: Int? {
        let place = gtk_drop_down_get_selected(widget.opaque)
        return place == GTK_INVALID_LIST_POSITION ? nil : Int(place)
    }

    /// The choices, then the one chosen - written only where the tree changed it or the choices changed, so the
    /// user's choice is never argued with; less than 0 chooses none.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool) {
        let changed = choices != self.choices
        if changed {
            self.choices = choices
            let list = Self.withCStrings(choices) { gtk_string_list_new($0) }
            gtk_drop_down_set_model(widget.opaque, list)
            g_object_unref(UnsafeMutableRawPointer(list))
        }
        guard changed || writeChosen else { return }
        gtk_drop_down_set_selected(
            widget.opaque, choices.indices.contains(chosen) ? guint(chosen) : guint(GTK_INVALID_LIST_POSITION))
    }

    /// `words` as a list of C strings ending in NULL, for as long as `body` runs.
    private static func withCStrings<Result>(
        _ words: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) -> Result
    ) -> Result {
        let copies = words.map { strdup($0) }
        defer { copies.forEach { free($0) } }
        let pointers = copies.map { UnsafePointer($0) } + [nil]
        return pointers.withUnsafeBufferPointer { body($0.baseAddress!) }
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
