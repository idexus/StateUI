// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A DatePicker and a TimePicker: the day or time, how it is written, the calendar or clock opened and
    /// closed, and the words' look.
    static func dates(_ registry: Registry<AndroidView>) {
        registry.add(DatePickerContract.self, create: { reports in
            let field = AndroidDateFieldView(.date)
            field.onChosen = { year, month, day in
                reports.report(
                    DatePickerContract.date, CalendarDate(year: year, month: month, day: day),
                    as: DatePickerContract.dateChanged)
            }
            field.onOpened = { reports.raise(DatePickerContract.opened) }
            field.onClosed = { reports.raise(DatePickerContract.closed) }
            return field
        }, members: { field in
            field.property(DatePickerContract.date) { view, date in view.setDate(date) }
            field.applies([DatePickerContract.minimumDate, DatePickerContract.maximumDate]) { view, values in
                view.setRange(earliest: values[DatePickerContract.minimumDate], latest: values[DatePickerContract.maximumDate])
            }
            field.property(DatePickerContract.format) { view, format in view.setFormat(format) }
            field.property(DatePickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            field.applies(fontMembers) { view, values in applyFont(view, values) }
            field.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            field.raises(DatePickerContract.dateChanged)
            field.raises(DatePickerContract.opened)
            field.raises(DatePickerContract.closed)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let field = AndroidDateFieldView(.time)
            field.onChosen = { hour, minute, _ in
                reports.report(
                    TimePickerContract.time, ClockTime(hour: hour, minute: minute), as: TimePickerContract.timeChanged)
            }
            field.onOpened = { reports.raise(TimePickerContract.opened) }
            field.onClosed = { reports.raise(TimePickerContract.closed) }
            return field
        }, members: { field in
            field.property(TimePickerContract.time) { view, time in view.setTime(time) }
            field.property(TimePickerContract.format) { view, format in view.setFormat(format) }
            field.property(TimePickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            field.applies(fontMembers) { view, values in applyFont(view, values) }
            field.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            field.raises(TimePickerContract.timeChanged)
            field.raises(TimePickerContract.opened)
            field.raises(TimePickerContract.closed)
        })
    }

    /// The look of a field's words, for a field that has no words of the tree's.
    private static let fontMembers: [any ContractMember] = [
        FontElementContract.fontSize, FontElementContract.fontAttributes, FontElementContract.fontFamily,
        TextStyleElementContract.textColor,
    ]

    private static func applyFont<Realized: ElementContract>(_ view: AndroidTextView, _ values: ElementValues<Realized>) {
        if values.changed(FontElementContract.fontSize) { view.setFontSize(values[FontElementContract.fontSize]) }
        if values.changed(FontElementContract.fontAttributes) {
            view.setFontAttributes(values[FontElementContract.fontAttributes])
        }
        if values.changed(FontElementContract.fontFamily) {
            view.setFontFamily(values[FontElementContract.fontFamily]?.text)
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setTextColor(values[TextStyleElementContract.textColor]?.propValue)
        }
    }
}
