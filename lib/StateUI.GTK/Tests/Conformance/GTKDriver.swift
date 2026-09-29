// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// The GTK host as the conformance suite drives it: each user's act through the signal or the call GTK's own input
/// takes, and each read from the widget itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class GTKDriver: HostDriver {
    let host = "GTK 4"
    let cannot: [String: String] = [:]
    let platformHasNone = GTKDriver.none()

    /// What GTK holds none of: what StateUI draws on GTK's snapshot, where StateUI's layout places the children,
    /// what StateUI measures and what the host cuts - each proven by its effect in another case.
    private static func none() -> [String: String] {
        var none = [
            "read growsWithText of TextEditor":
                "an editor's growing is StateUI's measuring, which no property of GTK's holds; its frames prove it",
            "read maximumLength of TextEditor":
                "GTK's text view keeps no bound: the host cuts what is typed, and typing proves it",
            "read maximumLength of TextField":
                "GTK bounds code points, not characters, so the host cuts what is typed; typing proves it",
            "read maximumLength of SearchField":
                "GTK bounds code points, not characters, so the host cuts what is typed; typing proves it",
        ]
        let shapes = ["Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"]
        let shapePaint = [
            "aspect", "renderTransform", "fill", "stroke", "strokeWidth", "strokeDashOffset", "strokeDashPattern",
            "strokeLineCap", "strokeLineJoin", "strokeMiterLimit",
        ]
        for shape in shapes {
            for member in shapePaint {
                none["read \(member) of \(shape)"] =
                    "StateUI draws a shape on GTK's snapshot, which holds none of its \(member); its drawing proves it"
            }
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            for member in ["background", "stroke", "strokeWidth", "shape"] {
                none["read \(member) of \(layout)"] =
                    "StateUI draws a layout's box on GTK's snapshot, which holds none of its \(member); its drawing proves it"
            }
            none["read padding of \(layout)"] =
                "GTK's panel places its children where StateUI's layout says; their frames prove it"
        }
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] = "GTK's panel places its children where StateUI's layout says; their frames prove it"
        }
        return none
    }

    /// What the families ask of a driver that GTK's has no path for yet says so, and stays empty in GTK's column
    /// with why, rather than failing: GTK's reads and acts are written on Linux (work-plan.md, ON LINUX).
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "GTK's driver has no path for it yet"
    }

    private var renderer: GTKRenderer?

    var register: HostRegister { GTKRealization.register }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        let renderer = GTKRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func step() {
        renderer?.step()
    }

    func turn() {
        renderer?.runtime.pump.turn()
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
        case (.type(let words), let field as GTKTextFieldView):
            type(words, into: field, keys: gtk_editable_get_delegate(field.widget.opaque))
        case (.type(let words), let editor as GTKTextEditorView):
            type(words, into: editor, keys: OpaquePointer(gtk_scrolled_window_get_child(editor.widget.opaque)))
        case (.submit, let field as GTKTextFieldView): GTKTestHost.emit(field.widget.opaque, "activate")
        case (.choose(let place), let picker as GTKPickerView): gtk_drop_down_set_selected(picker.widget.opaque, guint(place))
        case (.scroll(let offset), let items as GTKItemsView): try scroll(items, to: offset, on: element, act)
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? GTKElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as GTKToggleView): return toggle.isOn.propValue
        case (.value, let slider as GTKSliderView): return slider.value.propValue
        case (.minimum, let slider as GTKSliderView):
            return gtk_adjustment_get_lower(gtk_range_get_adjustment(slider.widget.of(GtkRange.self))).propValue
        case (.maximum, let slider as GTKSliderView):
            return gtk_adjustment_get_upper(gtk_range_get_adjustment(slider.widget.of(GtkRange.self))).propValue
        case (.value, let stepper as GTKStepperView): return stepper.value.propValue
        case (.progress, let bar as GTKProgressBarView): return bar.progress.propValue
        case (.isRunning, let spinner as GTKActivityIndicatorView): return spinner.isRunning.propValue
        case (.text, let label as GTKTextView): return label.text.propValue
        case (.text, let field as GTKTextFieldView): return field.text.propValue
        case (.text, let editor as GTKTextEditorView): return editor.text.propValue
        case (.text, let button as GTKButtonView): return button.text.propValue
        case (.text, let check as GTKCheckView): return check.text.propValue
        case (.selectedIndex, let picker as GTKPickerView): return picker.chosen.map(\.propValue)
        case (.options, let picker as GTKPickerView):
            guard let model = gtk_drop_down_get_model(picker.widget.opaque) else { return [String]().propValue }
            return (0..<g_list_model_get_n_items(model)).map { String(cString: gtk_string_list_get_string(model, $0)) }
                .propValue
        case (.isVisible, let view?): return (gtk_widget_get_visible(view.widget) != 0).propValue
        case (.opacity, let view?): return gtk_widget_get_opacity(view.widget).propValue
        case (.isEnabled, let view?): return (gtk_widget_get_sensitive(view.widget) != 0).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// Moves the scrolled window in `view` to `offset`, as a wheel does: through its adjustments, which hold it
    /// within what it shows - laid out first, as a frame lays out what the user sees before they scroll it.
    private func scroll(_ view: GTKView, to offset: Point, on element: MountedElement, _ act: UserAct) throws {
        renderer?.layOut()
        var child = gtk_widget_get_first_child(view.widget)
        while let each = child, g_type_check_instance_is_a(each.of(GTypeInstance.self), gtk_scrolled_window_get_type()) == 0 {
            child = gtk_widget_get_first_child(each)
        }
        guard let scrolled = child?.opaque else { throw DriverCannot(act, on: element) }
        gtk_adjustment_set_value(gtk_scrolled_window_get_hadjustment(scrolled), offset.x)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(scrolled), offset.y)
    }

    /// Types `words` into `input` as the keyboard leaves them - what does not lead to them chosen and deleted, the
    /// rest typed after what does - through the key bindings' signals of `keys`, which a read-only field refuses.
    private func type(_ words: String, into input: any GTKInputView, keys: OpaquePointer) {
        let kept = words.hasPrefix(input.text) ? input.text : ""
        if kept.isEmpty && !input.text.isEmpty {
            input.select(start: 0, length: input.text.unicodeScalars.count)
            GTKTestHost.emit(keys, "delete-from-cursor", [Double(GTK_DELETE_CHARS.rawValue), 1])
        } else {
            input.select(start: kept.unicodeScalars.count, length: 0)
        }
        GTKTestHost.emit(keys, "insert-at-cursor", words: String(words.dropFirst(kept.count)))
    }
}
