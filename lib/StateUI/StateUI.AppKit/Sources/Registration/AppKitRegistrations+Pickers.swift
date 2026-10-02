// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A choice, a day and a time: what the user picks, reported by member.
    static func pickers(_ registry: Registry<NSView>) {
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
                        attributes: values[FontElementContract.fontAttributes],
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
            let picker = AppKitDatePickerView()
            picker.onChosen = { day in reports.report(DatePickerContract.date, day, as: DatePickerContract.dateChanged) }
            return picker
        }, members: { picker in
            picker.applies([
                DatePickerContract.date, DatePickerContract.minimumDate, DatePickerContract.maximumDate,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                dress(view, values)
                view.setRange(earliest: values[DatePickerContract.minimumDate], latest: values[DatePickerContract.maximumDate])
                if values.changed(DatePickerContract.date) { view.setDate(values[DatePickerContract.date]) }
            }
            picker.raises(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = AppKitTimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.applies([
                TimePickerContract.time, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                dress(view, values)
                if values.changed(TimePickerContract.time) { view.setTime(values[TimePickerContract.time]) }
            }
            picker.raises(TimePickerContract.timeChanged)
        })
    }

    /// A day's or a time's field in the font, colour and state its element gives.
    private static func dress<Realized: ElementContract>(_ picker: NSDatePicker, _ values: ElementValues<Realized>) {
        picker.font = font(values)
        picker.textColor = values[TextStyleElementContract.textColor].flatMap { nsColor($0.propValue) } ?? .controlTextColor
        picker.isEnabled = values[VisualElementContract.isEnabled] ?? true
    }
}

#endif
