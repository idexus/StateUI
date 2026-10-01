// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// A Picker: a `GtkDropDown` over a list of its choices' words, the chosen one shown on its button.
/// Design: docs/design/platforms/gtk/controls.md#a-picker
@MainActor
final class GTKPickerView: GTKView {
    /// What the picker does when the user chooses, handed the chosen choice's place.
    var onChosen: ((Int) -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    private var wordsClass: String?

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
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let choices = write.choices {
            let list = withCStrings(choices) { gtk_string_list_new($0) }
            gtk_drop_down_set_model(widget.opaque, list)
            g_object_unref(UnsafeMutableRawPointer(list))
        }
        guard write.writesChoice else { return }
        gtk_drop_down_set_selected(widget.opaque, write.chosen.map { guint($0) } ?? guint(GTK_INVALID_LIST_POSITION))
    }

    /// The style sheet's class the button's words take their look from.
    func setWordsClass(_ name: String?) {
        swapClass(&wordsClass, to: name)
        invalidateMeasure()
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
