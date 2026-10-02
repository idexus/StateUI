// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A DatePicker or a TimePicker: the host's `StateUIDateField`, a field in the user's locale that opens the
/// platform's own calendar or clock. A day and a time stand by the host layer's rule (`CalendarArithmetic`), and
/// only the user's opening and closing are heard (`PickerOpening`).
/// Design: docs/design/platforms/android/controls.md#a-day-and-a-time
@MainActor
final class AndroidDateFieldView: AndroidTextualView {
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

    /// The earliest and the latest day the field holds, in order; nil for none.
    private var range: (earliest: CalendarDate?, latest: CalendarDate?) = (nil, nil)

    /// The day the field shows, once one was given or chosen.
    private var shown: CalendarDate?

    /// Who opened or closed the calendar or clock - only the user's are heard - and whether one shows.
    private var opening = PickerOpening()
    private var dialogShows = false

    init(_ kind: Kind) {
        self.kind = kind
        super.init { number in
            Java.new(
                JavaAPI.dateField, JavaAPI.newDateField, .object(AndroidRenderer.context), .long(number),
                .bool(kind == .time))
        }
    }

    /// The day the field shows, held within the range; one not in the calendar, or none, keeps the one it has.
    func setDate(_ date: CalendarDate?) {
        guard let date, let held = CalendarArithmetic.held(date, earliest: range.earliest, latest: range.latest) else {
            return
        }
        shown = held
        Java.call(
            reference, JavaAPI.setFieldDate, .int(Int32(clamping: held.year)), .int(Int32(held.month)),
            .int(Int32(held.day)))
    }

    /// The time the field shows, added up from midnight around the day; nil keeps the one it has.
    func setTime(_ time: ClockTime?) {
        guard let time else { return }
        let clock = CalendarArithmetic.clock(time)
        Java.call(reference, JavaAPI.setFieldTime, .int(Int32(clock.hour)), .int(Int32(clock.minute)))
    }

    /// The earliest and latest days the calendar offers, in order; nil for no bound. The day shown moves within them.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        range = CalendarArithmetic.range(earliest, latest)
        func day(_ date: CalendarDate?) -> [Int32] {
            date.map { [Int32(clamping: $0.year), Int32($0.month), Int32($0.day)] } ?? []
        }
        Java.frame {
            Java.call(
                reference, JavaAPI.setFieldRange, .object(Java.ints(day(range.earliest))),
                .object(Java.ints(day(range.latest))))
        }
        setDate(shown)
    }

    /// How the day or time is written; nil for the platform's.
    func setFormat(_ format: String?) {
        Java.frame { Java.call(reference, JavaAPI.setFieldFormat, .object(Java.string(format ?? ""))) }
    }

    /// Opens the calendar or clock, or closes it; the program's own change is heard by nobody.
    func setOpen(_ open: Bool) {
        guard opening.programAsks(open: open, shown: dialogShows) else { return }
        Java.call(reference, JavaAPI.setFieldOpen, .bool(open))
    }

    /// The user's choice, as the Java side hands it.
    func chose(_ first: Int, _ second: Int, _ third: Int) {
        if kind == .date { shown = CalendarDate(year: first, month: second, day: third) }
        onChosen?(first, second, third)
    }

    override func opened() {
        dialogShows = true
        if opening.heard(open: true) { onOpened?() }
    }

    override func closed() {
        dialogShows = false
        if opening.heard(open: false) { onClosed?() }
    }

    override func detach() {
        setOpen(false)
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
