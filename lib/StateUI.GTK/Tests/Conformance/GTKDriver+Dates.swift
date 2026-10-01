// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// A day and a time picker as the user meets them: the button opening the face, Escape closing it, a day clicked in
/// the calendar; and what they hold.
/// Design: docs/design/platforms/gtk/controls.md#a-day-and-a-time
extension GTKDriver {
    /// Performs `act` on a day or a time picker; false for an act it is not.
    func perform(_ act: UserAct, on picker: GTKPopoverPickerView) -> Bool {
        switch (act, picker) {
        case (.open, _): gtk_menu_button_popup(picker.widget.opaque)
        case (.close, _): gtk_popover_popdown(picker.popover.of(GtkPopover.self))
        case (.pickDate(let day), let dates as GTKDatePickerView):
            guard let native = g_date_time_new_local(Int32(day.year), Int32(day.month), Int32(day.day), 12, 0, 0) else {
                return false
            }
            gtk_calendar_select_day(dates.calendar.opaque, native)
            g_date_time_unref(native)
        // The user moves the hour and the minute each; the clock is set at once, and its minute's wheel tells it.
        case (.pickTime(let time), let times as GTKTimePickerView):
            ProgramWrite.perform { times.setTime(time) }
            GTKTestHost.emit(times.minutes.opaque, "value-changed")
        default: return false
        }
        return true
    }

    /// What a day or a time picker holds of `property`; nil for what it is not asked.
    func held(_ property: Prop, on picker: GTKPopoverPickerView) -> HostValue?? {
        switch (property, picker) {
        case (.isOpen, _): picker.isOpen.propValue
        case (.date, let dates as GTKDatePickerView): dates.date.propValue
        case (.minimumDate, let dates as GTKDatePickerView): .some(dates.range.earliest?.propValue)
        case (.maximumDate, let dates as GTKDatePickerView): .some(dates.range.latest?.propValue)
        case (.format, let dates as GTKDatePickerView): (Self.words(of: dates) == Self.shortForm(of: dates) ? "d" : "D").propValue
        case (.time, let times as GTKTimePickerView): times.time.propValue
        default: nil
        }
    }

    /// The words a picker's button shows.
    private static func words(of picker: GTKPopoverPickerView) -> String {
        String(cString: gtk_label_get_text(picker.label.opaque))
    }

    /// The day a DatePicker holds, in its short form.
    private static func shortForm(of picker: GTKDatePickerView) -> String {
        let day = gtk_calendar_get_date(picker.calendar.opaque)!
        defer { g_date_time_unref(day) }
        let words = g_date_time_format(day, "%x")!
        defer { g_free(words) }
        return String(cString: words)
    }
}
