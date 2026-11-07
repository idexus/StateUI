// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A DatePicker and a TimePicker: the day or the time, and what the user picks; the day's range; the words' look.
    /// The browser writes both in the user's own way, so no format reaches it.
    static func dates(_ registry: Registry<WebDOMView>) {
        registry.add(DatePickerContract.self, create: { reports in
            let picker = WebDatePickerView()
            picker.onChosen = { date in reports.report(DatePickerContract.date, date, as: DatePickerContract.dateChanged) }
            return picker
        }, members: { picker in
            picker.applies(DatePickerContract.minimum, DatePickerContract.maximum, DatePickerContract.date) {
                view, values in
                if values.changed(DatePickerContract.minimum) || values.changed(DatePickerContract.maximum) {
                    view.setRange(earliest: values[DatePickerContract.minimum], latest: values[DatePickerContract.maximum])
                }
                if values.changed(DatePickerContract.date) { view.setDate(values[DatePickerContract.date]) }
            }
            picker.applies(TextMembers.lookMembers) { view, values in view.setLook(TextMembers.look(of: values)) }
            picker.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.declares(DatePickerContract.dateChanged)
        })
        registry.add(TimePickerContract.self, create: { reports in
            let picker = WebTimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in view.setTime(time) }
            picker.applies(TextMembers.lookMembers) { view, values in view.setLook(TextMembers.look(of: values)) }
            picker.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.declares(TimePickerContract.timeChanged)
        })
    }
}
