// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
@_spi(Host) import StateUIHostConformance

/// The GTK host as the conformance suite drives it: each user's act through the signal or the call GTK's own input
/// takes, and each read from the widget itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class GTKDriver: HostDriver {
    let host = "GTK 4"
    let cannot: [String: String] = [:]
    private var renderer: GTKRenderer?

    var marks: HostMarks { GTKRealization.marks }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        let renderer = GTKRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.tree
    }

    func step() {
        guard let renderer else { return }
        GTKTestHost.pump(0.01)
        _ = renderer.core.runJobs()
        renderer.pump.turn()
        if renderer.frameClock.held { renderer.frame() }
    }

    func turn() {
        renderer?.pump.turn()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? GTKElement)?.view
        switch (act, view) {
        case (.activate, let button as GTKButtonView): button.click()
        case (.toggle, let toggle as GTKSwitchView): gtk_switch_set_active(toggle.widget.opaque, toggle.isOn ? 0 : 1)
        case (.toggle, let check as GTKCheckView): gtk_widget_activate(check.widget)
        case (.slide(let value), let slider as GTKSliderView): gtk_range_set_value(slider.widget.of(GtkRange.self), value)
        case (.step(let up), let stepper as GTKStepperView):
            gtk_spin_button_spin(stepper.widget.opaque, up ? GTK_SPIN_STEP_FORWARD : GTK_SPIN_STEP_BACKWARD, 0)
        case (.enterWords(let words), let stepper as GTKStepperView):
            gtk_editable_set_text(stepper.widget.opaque, words)
            gtk_spin_button_update(stepper.widget.opaque)
        case (.type(let words), let field as GTKTextFieldView): gtk_editable_set_text(field.widget.opaque, words)
        case (.type(let words), let editor as GTKTextEditorView):
            let text = gtk_scrolled_window_get_child(editor.widget.opaque)!
            gtk_text_buffer_set_text(gtk_text_view_get_buffer(text.of()), words, -1)
        case (.submit, let field as GTKTextFieldView): GTKTestHost.emit(field.widget.opaque, "activate")
        case (.choose(let place), let picker as GTKPickerView): gtk_drop_down_set_selected(picker.widget.opaque, guint(place))
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? GTKElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as GTKToggleView): return toggle.isOn.propValue
        case (.value, let slider as GTKSliderView): return slider.value.propValue
        case (.minimum, let slider as GTKSliderView): return slider.minimum.propValue
        case (.maximum, let slider as GTKSliderView): return slider.maximum.propValue
        case (.value, let stepper as GTKStepperView): return stepper.value.propValue
        case (.progress, let bar as GTKProgressBarView): return bar.progress.propValue
        case (.isRunning, let spinner as GTKActivityIndicatorView): return spinner.isRunning.propValue
        case (.text, let label as GTKTextView): return label.text.propValue
        case (.text, let field as GTKTextFieldView): return field.text.propValue
        case (.text, let editor as GTKTextEditorView): return editor.text.propValue
        case (.selectedIndex, let picker as GTKPickerView): return picker.chosen.map(\.propValue)
        case (.options, let picker as GTKPickerView):
            guard let model = gtk_drop_down_get_model(picker.widget.opaque) else { return [String]().propValue }
            return (0..<g_list_model_get_n_items(model)).map { String(cString: gtk_string_list_get_string(model, $0)) }
                .propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }
}
