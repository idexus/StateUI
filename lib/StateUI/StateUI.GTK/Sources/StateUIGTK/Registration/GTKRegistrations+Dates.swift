// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A DatePicker and a TimePicker: the day or the time, written in the user's own way, and what the user picks;
    /// the day's range; the calendar or the clock the user opens and closes; the words' look.
    static func dates(_ registry: Registry<GTKView>) {
        registry.add(DatePickerContract.self, create: { reports in
            let picker = GTKDatePickerView()
            picker.onChosen = { date in reports.report(DatePickerContract.date, date, as: DatePickerContract.dateChanged) }
            picker.onOpened = { reports.raise(DatePickerContract.opened) }
            picker.onClosed = { reports.raise(DatePickerContract.closed) }
            return picker
        }, members: { picker in
            picker.applies([DatePickerContract.minimumDate, DatePickerContract.maximumDate, DatePickerContract.date]) {
                view, values in
                if values.changed(DatePickerContract.minimumDate) || values.changed(DatePickerContract.maximumDate) {
                    view.setRange(earliest: values[DatePickerContract.minimumDate], latest: values[DatePickerContract.maximumDate])
                }
                if values.changed(DatePickerContract.date) { view.setDate(values[DatePickerContract.date]) }
            }
            picker.property(DatePickerContract.format) { view, format in view.setFormat(format) }
            picker.property(DatePickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            picker.applies(TextMembers.lookMembers) { view, values in applyWords(view, values) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(DatePickerContract.dateChanged)
            picker.raises(DatePickerContract.opened)
            picker.raises(DatePickerContract.closed)
        })
        registry.add(TimePickerContract.self, create: { reports in
            let picker = GTKTimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            picker.onOpened = { reports.raise(TimePickerContract.opened) }
            picker.onClosed = { reports.raise(TimePickerContract.closed) }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in view.setTime(time) }
            picker.property(TimePickerContract.format) { _, _ in }
            picker.property(TimePickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            picker.applies(TextMembers.lookMembers) { view, values in applyWords(view, values) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(TimePickerContract.timeChanged)
            picker.raises(TimePickerContract.opened)
            picker.raises(TimePickerContract.closed)
        })
    }

    private static func applyWords<Realized: ElementContract>(
        _ view: GTKPopoverPickerView, _ values: ElementValues<Realized>
    ) {
        view.setWordsClass(GTKStyleSheet.words(TextMembers.look(of: values), placeholder: nil))
    }
}
