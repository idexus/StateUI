// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Picker - its choices and the one chosen, which the user chooses too - and a DatePicker and a TimePicker:
    /// the day or the time picked, in the range the tree gives.
    static func pickers(_ registry: Registry<UIView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = UIKitPickerView()
            picker.onChosen = { place in
                reports.report(PickerContract.selectedIndex, place, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PickerContract.opened) }
            picker.onClosed = { reports.raise(PickerContract.closed) }
            return picker
        }, members: { picker in
            picker.applies([PickerContract.options, PickerContract.selectedIndex, PickerContract.title]) { view, values in
                view.setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex), title: values[PickerContract.title])
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })

        registry.add(DatePickerContract.self, create: { reports in
            let picker = UIKitDateTimePickerView(mode: .date)
            picker.onValueChanged = { lanes in
                guard let picked = CalendarDate(propValue: .numbers(lanes)) else { return }
                reports.report(DatePickerContract.date, picked, as: DatePickerContract.dateChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([
                DatePickerContract.date, DatePickerContract.minimumDate, DatePickerContract.maximumDate,
            ]) { view, values in
                view.apply(
                    value: values.changed(DatePickerContract.date)
                        ? values[DatePickerContract.date]?.propValue.numbers : nil,
                    minimum: values[DatePickerContract.minimumDate]?.propValue.numbers,
                    maximum: values[DatePickerContract.maximumDate]?.propValue.numbers)
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = UIKitDateTimePickerView(mode: .time)
            picker.onValueChanged = { lanes in
                guard let picked = ClockTime(propValue: .numbers(lanes)) else { return }
                reports.report(TimePickerContract.time, picked, as: TimePickerContract.timeChanged)
            }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in
                view.apply(value: time?.propValue.numbers, minimum: nil, maximum: nil)
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(TimePickerContract.timeChanged)
        })
    }
}
#endif
