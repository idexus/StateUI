// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A DatePicker: AppKit's field and stepper for a day, held within its range by the host layer's rule
/// (`CalendarArithmetic`).
@MainActor
final class AppKitDatePickerView: NSDatePicker {
    /// What the picker does as the user picks a day.
    var onChosen: ((CalendarDate) -> Void)?

    /// The earliest and the latest day the picker holds, in order; nil for none.
    private(set) var range: (earliest: CalendarDate?, latest: CalendarDate?) = (nil, nil)

    init() {
        super.init(frame: .zero)
        dressCivil(.yearMonthDay)
        target = self
        action = #selector(changed(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitDatePickerView is created in code")
    }

    /// The day the picker shows.
    var date: CalendarDate { day(of: dateValue) }

    /// The day shown, held within the range; one not in the calendar, or none, leaves the day shown.
    func setDate(_ date: CalendarDate?) {
        guard let date, let held = CalendarArithmetic.held(date, earliest: range.earliest, latest: range.latest),
              let instant = instant(of: held)
        else { return }
        ProgramWrite.perform { dateValue = instant }
    }

    /// The earliest and the latest day the picker holds; the day shown moves within them.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        range = CalendarArithmetic.range(earliest, latest)
        ProgramWrite.perform {
            minDate = range.earliest.flatMap(instant(of:))
            maxDate = range.latest.flatMap(instant(of:))
        }
        setDate(date)
    }

    @objc private func changed(_ sender: NSDatePicker) {
        guard !ProgramWrite.isWriting else { return }
        onChosen?(date)
    }

    /// The earliest and the latest day AppKit's field offers.
    var earliestForTesting: CalendarDate? { minDate.map(day(of:)) }
    var latestForTesting: CalendarDate? { maxDate.map(day(of:)) }

    /// Picks `day` as the user does, held within the range.
    func chooseForTesting(_ day: CalendarDate) {
        guard let held = CalendarArithmetic.held(day, earliest: range.earliest, latest: range.latest),
              let instant = instant(of: held)
        else { return }
        dateValue = instant
        changed(self)
    }
}

#endif
