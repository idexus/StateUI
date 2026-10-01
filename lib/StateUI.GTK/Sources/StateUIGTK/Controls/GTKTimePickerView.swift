// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK
import Glibc

/// A TimePicker: its time written on its button in the user's clock, and in its popover the clock GNOME's own
/// applications set a time with - an hour and a minute, each a `GtkSpinButton` going round, and where the user's
/// clock has twelve hours the half of the day.
/// Design: docs/design/platforms/gtk/controls.md#a-day-and-a-time
@MainActor
final class GTKTimePickerView: GTKPopoverPickerView {
    /// What the picker does as the user sets a time.
    var onChosen: ((ClockTime) -> Void)?

    /// The hour and the minute.
    let hours: GTKWidget
    let minutes: GTKWidget

    /// The button turning the half of the day; nil on a 24-hour clock.
    let half: GTKWidget?

    /// Whether the clock shows the afternoon, on a 12-hour clock.
    private var afternoon = false

    init() {
        let twelve = !GTKEnvironment.locale.uses24HourClock
        hours = Self.wheel(twelve ? 1...12 : 0...23)
        minutes = Self.wheel(0...59)
        half = twelve ? gtk_button_new() : nil
        let face = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        for margin in [gtk_widget_set_margin_top, gtk_widget_set_margin_bottom] { margin(face, 6) }
        gtk_box_append(face.of(GtkBox.self), hours)
        gtk_box_append(face.of(GtkBox.self), gtk_label_new(":"))
        gtk_box_append(face.of(GtkBox.self), minutes)
        if let half {
            gtk_widget_set_valign(half, GTK_ALIGN_CENTER)
            gtk_box_append(face.of(GtkBox.self), half)
        }
        super.init(face: face)
        for wheel in [hours, minutes] {
            connectSignal(UnsafeMutableRawPointer(wheel), "value-changed", number: number) {
                (_: UnsafeMutableRawPointer?, data: gpointer?) in
                MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTimePickerView)?.set() }
            }
        }
        if let half {
            connectSignal(UnsafeMutableRawPointer(half), "clicked", number: number) {
                (_: UnsafeMutableRawPointer?, data: gpointer?) in
                MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTimePickerView)?.turnTheHalf() }
            }
        }
        write()
    }

    /// The time the clock holds.
    var time: ClockTime {
        let hour = Int(gtk_spin_button_get_value_as_int(hours.opaque))
        let minute = Int(gtk_spin_button_get_value_as_int(minutes.opaque))
        guard half != nil else { return ClockTime(hour: hour, minute: minute) }
        return ClockTime(hour: hour % 12 + (afternoon ? 12 : 0), minute: minute)
    }

    /// The time shown, added up from midnight around the day (`CalendarArithmetic`); none leaves the time shown.
    func setTime(_ time: ClockTime?) {
        guard let time else { return }
        let clock = CalendarArithmetic.clock(time)
        afternoon = clock.hour >= 12
        let hour = half == nil ? clock.hour : (clock.hour % 12 == 0 ? 12 : clock.hour % 12)
        gtk_spin_button_set_value(hours.opaque, Double(hour))
        gtk_spin_button_set_value(minutes.opaque, Double(clock.minute))
        write()
    }

    /// The user set the hour or the minute.
    private func set() {
        write()
        onChosen?(time)
    }

    private func turnTheHalf() {
        afternoon.toggle()
        set()
    }

    /// Writes the time on the button and the half of the day on its own.
    private func write() {
        let clock = time
        if let half {
            gtk_button_set_label(half.of(GtkButton.self), Self.halves[afternoon ? 1 : 0])
        }
        guard let day = g_date_time_new_local(2001, 1, 1, Int32(clock.hour), Int32(clock.minute), 0) else { return }
        defer { g_date_time_unref(day) }
        guard let words = g_date_time_format(day, half == nil ? "%H:%M" : "%-l:%M %p") else { return }
        defer { g_free(words) }
        setWords(String(cString: words))
    }

    /// The words the user's locale names the morning and the afternoon by.
    private static let halves = [nl_item(AM_STR), nl_item(PM_STR)].enumerated().map { place, item in
        let words = String(cString: nl_langinfo(item))
        return words.isEmpty ? (place == 0 ? "AM" : "PM") : words
    }

    /// A spin button standing upright over `range`, going round past its ends, its number written in two digits.
    private static func wheel(_ range: ClosedRange<Int>) -> GTKWidget {
        let wheel = gtk_spin_button_new_with_range(Double(range.lowerBound), Double(range.upperBound), 1)!
        gtk_orientable_set_orientation(wheel.opaque, GTK_ORIENTATION_VERTICAL)
        gtk_spin_button_set_wrap(wheel.opaque, 1)
        gtk_spin_button_set_numeric(wheel.opaque, 1)
        connectAnswering(UnsafeMutableRawPointer(wheel), "output", number: 0) { wheel, _ in
            let number = Int(gtk_spin_button_get_value_as_int(OpaquePointer(wheel)))
            gtk_editable_set_text(OpaquePointer(wheel), (number < 10 ? "0" : "") + String(number))
            return 1
        }
        return wheel
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
