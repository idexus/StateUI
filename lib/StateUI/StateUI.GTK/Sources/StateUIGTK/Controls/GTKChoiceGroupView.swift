// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// A picker offering its values as segments or as radio buttons: a row of GTK's toggle buttons, linked, or a column
/// of its check buttons drawn as radio buttons - each set grouped, so GTK keeps one active.
/// Design: docs/design/platforms/gtk/controls.md#a-pickers-segments-and-radio-buttons
@MainActor
final class GTKChoiceGroupView: GTKView, GTKChoosing {
    var onChosen: ((Int) -> Void)?

    /// Whether the values stand as segments rather than as radio buttons.
    private let segmented: Bool

    /// A button for each value, in order.
    private var buttons: [GTKWidget] = []

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    private var wordsClass: String?

    init(segmented: Bool) {
        self.segmented = segmented
        super.init { _ in
            gtk_box_new(segmented ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL, segmented ? 0 : 6)
        }
        if segmented { gtk_widget_add_css_class(widget, "linked") }
    }

    var chosen: Int? { buttons.firstIndex(where: isActive) }

    var offered: [String] { written.choices }

    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let shown = write.choices { offer(shown) }
        guard write.writesChoice else { return }
        for (place, button) in buttons.enumerated() { setActive(button, place == write.chosen) }
    }

    /// A button for each of `shown`, in order, the first leading the group the others join.
    private func offer(_ shown: [String]) {
        for button in buttons { gtk_box_remove(widget.of(GtkBox.self), button) }
        buttons = shown.map { caption in
            segmented ? gtk_toggle_button_new_with_label(caption)! : gtk_check_button_new_with_label(caption)!
        }
        for button in buttons {
            if let leader = buttons.first, button != leader {
                if segmented {
                    gtk_toggle_button_set_group(button.of(GtkToggleButton.self), leader.of(GtkToggleButton.self))
                } else {
                    gtk_check_button_set_group(button.of(GtkCheckButton.self), leader.of(GtkCheckButton.self))
                }
            }
            gtk_box_append(widget.of(GtkBox.self), button)
            connectSignal(UnsafeMutableRawPointer(button), "toggled", number: number) { _, data in
                MainActor.assumeIsolated {
                    guard let view = GTKView.find(viewNumber(data)) as? GTKChoiceGroupView else { return }
                    view.toggled()
                }
            }
        }
    }

    /// A button turned on or off: the one now on is the choice.
    private func toggled() {
        guard let chosen else { return }
        onChosen?(chosen)
    }

    func choose(_ place: Int) {
        guard buttons.indices.contains(place) else { return }
        setActive(buttons[place], true)
    }

    func setWordsClass(_ name: String?) {
        swapClass(&wordsClass, to: name)
        invalidateMeasure()
    }

    private func isActive(_ button: GTKWidget) -> Bool {
        segmented
            ? gtk_toggle_button_get_active(button.of(GtkToggleButton.self)) != 0
            : gtk_check_button_get_active(button.of(GtkCheckButton.self)) != 0
    }

    private func setActive(_ button: GTKWidget, _ active: Bool) {
        if segmented {
            gtk_toggle_button_set_active(button.of(GtkToggleButton.self), active ? 1 : 0)
        } else {
            gtk_check_button_set_active(button.of(GtkCheckButton.self), active ? 1 : 0)
        }
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
