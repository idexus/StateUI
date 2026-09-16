// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it
/// reports. Families move here from `MountedNode`'s switch one at a time; an
/// element no registration answers is still made there.
@MainActor
enum AppKitRegistrations {
    /// The registry, built once.
    static let registry: Registry<NSView> = {
        let registry = Registry<NSView>()

        indicators(registry)
        toggles(registry)
        values(registry)
        pickers(registry)

        return registry
    }()

    /// Progress and activity: one value each, and no event.
    private static func indicators(_ registry: Registry<NSView>) {
        registry.add(ProgressBarContract.self, create: { _ in AppKitProgressView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in
                view.apply(progress: progress ?? 0)
            }
        }

        registry.add(ActivityIndicatorContract.self, create: { _ in AppKitActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in
                view.apply(running: running ?? false)
            }
        }
    }

    /// A switch, a check box and a radio button: one value the reader turns on,
    /// taken whole with the enabled state - and, for the radio button, the
    /// caption it draws in the font and case the tree describes. Which of the
    /// set's other buttons lose their check is the host's, not the view's: a
    /// set is named across the window, and only the tree knows who is in it.
    private static func toggles(_ registry: Registry<NSView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AppKitSwitchView()
            toggle.onToggled = { on in
                reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
            }
            return toggle
        }, members: { toggle in
            toggle.applies([SwitchContract.isOn, VisualElementContract.isEnabled]) { view, values in
                view.apply(
                    toggled: values[SwitchContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            toggle.raises(SwitchContract.toggled)
        })

        registry.add(CheckBoxContract.self, create: { reports in
            let box = AppKitCheckBoxView()
            box.onToggled = { on in
                reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled)
            }
            return box
        }, members: { box in
            box.applies([
                CheckBoxContract.isOn, VisualElementContract.isEnabled, TintElementContract.tint,
            ]) { view, values in
                view.apply(
                    checked: values[CheckBoxContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) })
            }
            box.raises(CheckBoxContract.toggled)
        })

        registry.add(RadioButtonContract.self, create: { reports in
            let radio = AppKitRadioButtonView()
            radio.onSelected = {
                reports.report(RadioButtonContract.isOn, true, as: RadioButtonContract.toggled)
            }
            return radio
        }, members: { radio in
            radio.applies([
                RadioButtonContract.isOn, TextElementContract.text, TextElementContract.textCase,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    checked: values[RadioButtonContract.isOn] ?? false,
                    text: appKitTextCased(
                        values[TextElementContract.text] ?? "",
                        values[TextElementContract.textCase]?.rawValue),
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            radio.raises(RadioButtonContract.toggled)
        })
    }

    /// A slider and a stepper: one number the reader moves, inside the range
    /// its element describes. The value is written onto the native control only
    /// where the tree changed it, so a hand on the thumb is never argued with.
    private static func values(_ registry: Registry<NSView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = AppKitSliderView()
            slider.onValueChanged = { moved in
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            slider.onDragStarted = { reports.raise(SliderContract.dragStarted) }
            slider.onDragCompleted = { reports.raise(SliderContract.dragCompleted) }
            return slider
        }, members: { slider in
            slider.applies([
                SliderContract.value, SliderContract.minimum, SliderContract.maximum,
                TintElementContract.tint, VisualElementContract.isEnabled,
            ]) { view, values in
                let moved = values[SliderContract.value]

                view.apply(
                    value: moved,
                    writeValue: values.changed(SliderContract.value) && moved != nil,
                    minimum: values[SliderContract.minimum] ?? 0,
                    maximum: values[SliderContract.maximum] ?? 1,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            slider.raises(SliderContract.valueChanged)
            slider.raises(SliderContract.dragStarted)
            slider.raises(SliderContract.dragCompleted)
        })

        registry.add(StepperContract.self, create: { reports in
            let stepper = AppKitStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(StepperContract.value, stepped, as: StepperContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies([
                StepperContract.value, StepperContract.minimum, StepperContract.maximum,
                StepperContract.step, VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[StepperContract.value],
                    writeValue: values.changed(StepperContract.value),
                    minimum: values[StepperContract.minimum] ?? 0,
                    maximum: values[StepperContract.maximum] ?? 100,
                    step: values[StepperContract.step] ?? 1,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            stepper.raises(StepperContract.valueChanged)
        })
    }

    /// A choice, a date and a time: what the reader picks, reported by member.
    /// A date and a time travel as the lanes their types carry, which is how
    /// StateUI keeps a civil date out of an absolute instant's zone.
    private static func pickers(_ registry: Registry<NSView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = AppKitPickerView()
            picker.onSelectionChanged = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PickerContract.opened) }
            picker.onClosed = { reports.raise(PickerContract.closed) }
            return picker
        }, members: { picker in
            picker.applies([
                PickerContract.options, PickerContract.selectedIndex, PickerContract.title,
                PickerContract.isOpen, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                TintElementContract.tint, TextAlignmentElementContract.horizontalTextAlignment,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    items: values[PickerContract.options] ?? [],
                    selectedIndex: values[PickerContract.selectedIndex] ?? -1,
                    writeSelection: values.changed(PickerContract.selectedIndex),
                    title: values[PickerContract.title],
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    alignment: appKitTextAlignment(
                        values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue),
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    open: values[PickerContract.isOpen] ?? false,
                    writeOpen: values.changed(PickerContract.isOpen))
            }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })

        registry.add(DatePickerContract.self, create: { reports in
            let picker = AppKitDateTimePickerView(mode: .date)
            picker.onValueChanged = { lanes in
                guard let picked = CalendarDate(propValue: .numbers(lanes)) else { return }

                reports.report(DatePickerContract.date, picked, as: DatePickerContract.dateChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([
                DatePickerContract.date, DatePickerContract.minimumDate, DatePickerContract.maximumDate,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[DatePickerContract.date]?.propValue.numbers,
                    writeValue: values.changed(DatePickerContract.date),
                    minimum: values[DatePickerContract.minimumDate]?.propValue.numbers,
                    maximum: values[DatePickerContract.maximumDate]?.propValue.numbers,
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            picker.raises(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = AppKitDateTimePickerView(mode: .time)
            picker.onValueChanged = { lanes in
                guard let picked = ClockTime(propValue: .numbers(lanes)) else { return }

                reports.report(TimePickerContract.time, picked, as: TimePickerContract.timeChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([
                TimePickerContract.time, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[TimePickerContract.time]?.propValue.numbers,
                    writeValue: values.changed(TimePickerContract.time),
                    minimum: nil,
                    maximum: nil,
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            picker.raises(TimePickerContract.timeChanged)
        })
    }
}
#endif
