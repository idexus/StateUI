// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A choice, a day, a time and a color: what the user picks, reported by member.
    static func pickers(_ registry: Registry<NSView>) {
        // Each presentation is another control: the picker is made as the one it is made with.
        registry.add(PickerContract.self, create: { reports -> NSView in
            let picker: any AppKitChoosing = switch PickerChoices.presentation(made: reports.made) {
            case .menu: AppKitPickerView()
            case .segmented: AppKitSegmentedPickerView()
            case .radio: AppKitRadioPickerView()
            }
            picker.onSelectionChanged = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PopupElementContract.opened) }
            picker.onClosed = { reports.raise(PopupElementContract.closed) }
            return picker
        }, members: { (picker: Registration<PickerContract, NSView>) in
            picker.applies(
                PickerContract.options, PickerContract.selectedIndex, PlaceholderElementContract.placeholder, PopupElementContract.isOpen,
                FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
                FontElementContract.fontWeight, FontElementContract.textStyle, TextColorElementContract.textColor,
                TintElementContract.tint, TextAlignmentElementContract.horizontalTextAlignment,
                EnabledElementContract.isEnabled) { view, values in
                (view as! any AppKitChoosing).apply(
                    items: values[PickerContract.options] ?? [],
                    selectedIndex: values[PickerContract.selectedIndex] ?? -1,
                    writeSelection: values.changed(PickerContract.selectedIndex),
                    title: values[PlaceholderElementContract.placeholder],
                    font: Self.font(values),
                    textColor: values[TextColorElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    enabled: values[EnabledElementContract.isEnabled] ?? true,
                    open: values[PopupElementContract.isOpen] ?? false,
                    writeOpen: values.changed(PopupElementContract.isOpen))
            }
            picker.declares(PickerContract.selectedIndexChanged)
            picker.declares(PopupElementContract.opened)
            picker.declares(PopupElementContract.closed)
        })

        registry.add(DatePickerContract.self, create: { reports in
            let picker = AppKitDatePickerView()
            picker.onChosen = { day in reports.report(DatePickerContract.date, day, as: DatePickerContract.dateChanged) }
            return picker
        }, members: { picker in
            picker.applies(
                DatePickerContract.date, DatePickerContract.minimum, DatePickerContract.maximum,
                FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
                FontElementContract.fontWeight, FontElementContract.textStyle, TextColorElementContract.textColor,
                EnabledElementContract.isEnabled) { view, values in
                dress(view, values)
                view.setRange(earliest: values[DatePickerContract.minimum], latest: values[DatePickerContract.maximum])
                if values.changed(DatePickerContract.date) { view.setDate(values[DatePickerContract.date]) }
            }
            picker.declares(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = AppKitTimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.applies(
                TimePickerContract.time, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, FontElementContract.fontWeight, FontElementContract.textStyle,
                TextColorElementContract.textColor, EnabledElementContract.isEnabled) { view, values in
                dress(view, values)
                if values.changed(TimePickerContract.time) { view.setTime(values[TimePickerContract.time]) }
            }
            picker.declares(TimePickerContract.timeChanged)
        })

        registry.add(ColorPickerContract.self, create: { reports in
            let picker = AppKitColorPickerView()
            picker.onChosen = { color in
                reports.report(ColorPickerContract.color, color, as: ColorPickerContract.colorChanged)
            }
            return picker
        }, members: { picker in
            picker.applies(
                ColorPickerContract.color, ColorPickerContract.choosesOpacity, EnabledElementContract.isEnabled
            ) { view, values in
                view.apply(
                    color: values[ColorPickerContract.color] ?? ColorChoice.unset,
                    write: values.changed(ColorPickerContract.color),
                    choosesOpacity: values[ColorPickerContract.choosesOpacity] ?? false,
                    enabled: values[EnabledElementContract.isEnabled] ?? true)
            }
            picker.declares(ColorPickerContract.colorChanged)
        })
    }

    /// A day's or a time's field in the font, color and state its element gives.
    private static func dress<Realized: ElementContract>(_ picker: NSDatePicker, _ values: ElementValues<Realized>) {
        picker.font = font(values)
        picker.textColor = values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) } ?? .controlTextColor
        picker.isEnabled = values[EnabledElementContract.isEnabled] ?? true
    }
}

#endif
