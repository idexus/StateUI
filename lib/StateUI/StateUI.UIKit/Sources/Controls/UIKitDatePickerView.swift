// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A DatePicker: UIKit's own, compact, a day held within its range by the host layer's rule (`CalendarArithmetic`).
/// The user's pick is reported; the program's is only shown.
@MainActor
final class UIKitDatePickerView: UIDatePicker {
    /// What the picker does as the user picks a day.
    var onChosen: ((CalendarDate) -> Void)?

    /// The earliest and the latest day the picker holds, in order; nil for none.
    private(set) var range: (earliest: CalendarDate?, latest: CalendarDate?) = (nil, nil)

    init() {
        super.init(frame: .zero)
        dressCivil(.date)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onChosen?(day)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitDatePickerView is made in code")
    }

    /// The day the picker shows.
    var day: CalendarDate { Self.day(of: date) }

    /// The day shown, held within the range; one not in the calendar, or none, leaves the day shown.
    func setDay(_ day: CalendarDate?) {
        guard let day, let held = CalendarArithmetic.held(day, earliest: range.earliest, latest: range.latest),
              let instant = Self.instant(of: held)
        else { return }
        date = instant
    }

    /// The earliest and the latest day the picker holds; the day shown moves within them.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        range = CalendarArithmetic.range(earliest, latest)
        minimumDate = range.earliest.flatMap(Self.instant(of:))
        maximumDate = range.latest.flatMap(Self.instant(of:))
        setDay(day)
    }
}
#endif
