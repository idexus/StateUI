// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A choice, a date and a time: what the user picks, reported by member.
    /// A date and a time travel as the lanes their types carry, which is how
    /// StateUI keeps a civil date out of an absolute instant's zone.
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
