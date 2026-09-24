// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A DatePicker or a TimePicker: the host's `StateUIDateField`, a field in the user's locale that opens the
/// platform's own calendar or clock.
/// Design: docs/design/platforms/android/controls.md#a-day-and-a-time
@MainActor
final class AndroidDateFieldView: AndroidTextView {
    /// What the field holds.
    enum Kind {
        case date
        case time
    }

    /// What the field holds.
    let kind: Kind

    /// What the field does when the user chooses: a year, month and day, or an hour, a minute and 0.
    var onChosen: ((Int, Int, Int) -> Void)?

    /// What the field does when the user opens its calendar or clock, and when it closes.
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    init(_ kind: Kind) {
        self.kind = kind
        super.init { number in
            Java.new(
                JavaAPI.dateField, JavaAPI.newDateField, .object(AndroidRenderer.context), .long(number),
                .bool(kind == .time))
        }
    }

    /// The day the field shows; nil keeps the one it has.
    func setDate(_ date: CalendarDate?) {
        guard let date else { return }
        Java.call(reference, JavaAPI.setFieldDate, .int(Int32(date.year)), .int(Int32(date.month)), .int(Int32(date.day)))
    }

    /// The time the field shows; nil keeps the one it has.
    func setTime(_ time: ClockTime?) {
        guard let time else { return }
        Java.call(reference, JavaAPI.setFieldTime, .int(Int32(time.hour)), .int(Int32(time.minute)))
    }

    /// The earliest and latest days the calendar offers; nil for no bound.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        func day(_ date: CalendarDate?) -> [Int32] {
            date.map { [Int32($0.year), Int32($0.month), Int32($0.day)] } ?? []
        }
        Java.frame {
            Java.call(reference, JavaAPI.setFieldRange, .object(Java.ints(day(earliest))), .object(Java.ints(day(latest))))
        }
    }

    /// How the day or time is written; nil for the platform's.
    func setFormat(_ format: String?) {
        Java.frame { Java.call(reference, JavaAPI.setFieldFormat, .object(Java.string(format ?? ""))) }
    }

    /// Opens the calendar or clock, or closes it; the program's own change reports nothing.
    func setOpen(_ open: Bool) {
        Java.call(reference, JavaAPI.setFieldOpen, .bool(open))
    }

    /// The user's choice, as the Java side hands it.
    func chose(_ first: Int, _ second: Int, _ third: Int) {
        onChosen?(first, second, third)
    }

    override func opened() {
        onOpened?()
    }

    override func closed() {
        onClosed?()
    }

    override func detach() {
        setOpen(false)
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
