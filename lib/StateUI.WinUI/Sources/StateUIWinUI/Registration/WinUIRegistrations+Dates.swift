// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A DatePicker and a TimePicker: the day or the time, written in the user's own way, and what the user picks;
    /// the day's bounds and its calendar, which the user opens and closes.
    static func dates(_ registry: Registry<WinUIView>) {
        registry.add(DatePickerContract.self, create: { reports in
            let picker = WinUIDatePickerView()
            picker.onChosen = { date in reports.report(DatePickerContract.date, date, as: DatePickerContract.dateChanged) }
            picker.onOpened = { reports.raise(DatePickerContract.opened) }
            picker.onClosed = { reports.raise(DatePickerContract.closed) }
            return picker
        }, members: { picker in
            picker.property(DatePickerContract.date) { view, date in view.setDate(date) }
            picker.applies([DatePickerContract.minimumDate, DatePickerContract.maximumDate]) { view, values in
                view.setRange(earliest: values[DatePickerContract.minimumDate], latest: values[DatePickerContract.maximumDate])
            }
            picker.property(DatePickerContract.format) { view, format in view.setFormat(format) }
            picker.property(DatePickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            picker.applies(dayMembers) { view, values in applyDayWords(view, values) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(DatePickerContract.dateChanged)
            picker.raises(DatePickerContract.opened)
            picker.raises(DatePickerContract.closed)
        })
        registry.add(TimePickerContract.self, create: { reports in
            let picker = WinUITimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in view.setTime(time) }
            picker.property(TimePickerContract.format) { _, _ in }
            picker.applies(dayMembers) { view, values in applyDayWords(view, values) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(TimePickerContract.timeChanged)
        })
    }

    /// The font and the colour a day or a time is written in.
    private static let dayMembers: [any ContractMember] = [
        FontElementContract.fontSize, FontElementContract.fontAttributes, FontElementContract.fontFamily,
        TextStyleElementContract.textColor,
    ]

    private static func applyDayWords<Realized: ElementContract>(_ view: WinUIView, _ values: ElementValues<Realized>) {
        view.setFont(
            size: values[FontElementContract.fontSize], attributes: values[FontElementContract.fontAttributes],
            family: values[FontElementContract.fontFamily]?.text)
        view.setForeground(values[TextStyleElementContract.textColor]?.propValue)
    }
}
