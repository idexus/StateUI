// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A DatePicker and a TimePicker: the day or the time, written in the user's own way, and what the user picks;
    /// the day's bounds and its calendar, which the user opens and closes.
    static func dates(_ registry: Registry<WinUIView>) {
        registry.add(DatePickerContract.self, create: { reports in
            let picker = WinUIDatePickerView()
            picker.onChosen = { date in reports.report(DatePickerContract.date, date, as: DatePickerContract.dateChanged) }
            picker.onOpened = { reports.raise(PopupElementContract.opened) }
            picker.onClosed = { reports.raise(PopupElementContract.closed) }
            return picker
        }, members: { picker in
            picker.property(DatePickerContract.date) { view, date in view.setDate(date) }
            picker.applies(DatePickerContract.minimum, DatePickerContract.maximum) { view, values in
                view.setRange(earliest: values[DatePickerContract.minimum], latest: values[DatePickerContract.maximum])
            }
            picker.property(DatePickerContract.format) { view, format in view.setFormat(format) }
            picker.property(PopupElementContract.isOpen) { view, open in view.setOpen(open ?? false) }
            picker.applies(TextMembers.lookMembers) { view, values in view.setLook(TextMembers.look(of: values)) }
            picker.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.declares(DatePickerContract.dateChanged)
            picker.declares(PopupElementContract.opened)
            picker.declares(PopupElementContract.closed)
        })
        registry.add(TimePickerContract.self, create: { reports in
            let picker = WinUITimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in view.setTime(time) }
            picker.property(TimePickerContract.format) { _, _ in }
            picker.applies(TextMembers.lookMembers) { view, values in view.setLook(TextMembers.look(of: values)) }
            picker.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.declares(TimePickerContract.timeChanged)
        })
    }
}
