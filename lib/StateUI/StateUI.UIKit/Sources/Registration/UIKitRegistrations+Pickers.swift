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
            picker.applies([PickerContract.options, PickerContract.selectedIndex, PickerContract.placeholder]) { view, values in
                view.setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex), title: values[PickerContract.placeholder])
            }
            picker.applies([
                FontElementContract.fontSize, FontElementContract.fontFamily, FontElementContract.fontAttributes,
                TextStyleElementContract.textColor, TextAlignmentElementContract.horizontalTextAlignment,
            ]) { view, values in
                view.setLook(
                    TextMembers.look(of: values),
                    alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
            }
            picker.property(TintElementContract.tint) { view, tint in
                view.setTint(tint.flatMap { UIColor(stateUI: $0.propValue) })
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })

        registry.add(DatePickerContract.self, create: { reports in
            let picker = UIKitDatePickerView()
            picker.onChosen = { day in reports.report(DatePickerContract.date, day, as: DatePickerContract.dateChanged) }
            return picker
        }, members: { picker in
            picker.applies([
                DatePickerContract.date, DatePickerContract.minimumDate, DatePickerContract.maximumDate,
            ]) { view, values in
                view.setRange(earliest: values[DatePickerContract.minimumDate], latest: values[DatePickerContract.maximumDate])
                if values.changed(DatePickerContract.date) { view.setDay(values[DatePickerContract.date]) }
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = UIKitTimePickerView()
            picker.onChosen = { time in reports.report(TimePickerContract.time, time, as: TimePickerContract.timeChanged) }
            return picker
        }, members: { picker in
            picker.property(TimePickerContract.time) { view, time in view.setTime(time) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            picker.raises(TimePickerContract.timeChanged)
        })
    }
}
#endif
