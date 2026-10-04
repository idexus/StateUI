// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A DatePicker: its day written on its button in the user's own way, a `GtkCalendar` in its popover. The calendar
/// offers every day; one the user picks past the range stands at its end (`CalendarArithmetic`).
/// Design: docs/design/platforms/gtk/controls.md#a-day-and-a-time
@MainActor
final class GTKDatePickerView: GTKPopoverPickerView {
    /// What the picker does as the user picks a day.
    var onChosen: ((CalendarDate) -> Void)?

    /// The calendar.
    let calendar: GTKWidget

    /// The earliest and the latest day the picker holds, in order; nil for none.
    private(set) var range: (earliest: CalendarDate?, latest: CalendarDate?) = (nil, nil)

    /// Whether the day is written in its long form.
    private var isLong = false

    init() {
        calendar = gtk_calendar_new()!
        super.init(face: calendar)
        connectSignal(UnsafeMutableRawPointer(calendar), "day-selected", number: number) {
            (_: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKDatePickerView)?.picked() }
        }
        write()
    }

    /// The day the calendar holds.
    var date: CalendarDate {
        let day = gtk_calendar_get_date(calendar.opaque)!
        defer { g_date_time_unref(day) }
        return CalendarDate(
            year: Int(g_date_time_get_year(day)), month: Int(g_date_time_get_month(day)),
            day: Int(g_date_time_get_day_of_month(day)))
    }

    /// The day shown, held within the range; one not in the calendar, or none, leaves the day shown.
    func setDate(_ date: CalendarDate?) {
        guard let date, let held = CalendarArithmetic.held(date, earliest: range.earliest, latest: range.latest) else {
            return
        }
        select(held)
    }

    /// The earliest and the latest day the picker holds; the day shown moves within them.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        range = CalendarArithmetic.range(earliest, latest)
        setDate(date)
    }

    /// How the day is written: "D" the long form, anything else the short.
    func setFormat(_ format: String?) {
        isLong = format == "D"
        write()
    }

    private func select(_ day: CalendarDate) {
        guard day != date, let native = g_date_time_new_local(Int32(day.year), Int32(day.month), Int32(day.day), 12, 0, 0)
        else { return }
        defer { g_date_time_unref(native) }
        gtk_calendar_select_day(calendar.opaque, native)
        write()
    }

    /// The day the user picked: held within the range, then told.
    private func picked() {
        let picked = date
        let held = CalendarArithmetic.held(picked, earliest: range.earliest, latest: range.latest) ?? picked
        if held != picked { ProgramWrite.perform { select(held) } }
        write()
        onChosen?(held)
    }

    /// Writes the day on the button.
    private func write() {
        let day = gtk_calendar_get_date(calendar.opaque)!
        defer { g_date_time_unref(day) }
        guard let words = g_date_time_format(day, isLong ? "%A, %-e %B %Y" : "%x") else { return }
        defer { g_free(words) }
        setWords(String(cString: words))
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
