// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TimePicker: AppKit's field and stepper for an hour and a minute, a time added up from midnight around the day
/// by the host layer's rule (`CalendarArithmetic`).
@MainActor
final class AppKitTimePickerView: NSDatePicker {
    /// What the picker does as the user picks a time.
    var onChosen: ((ClockTime) -> Void)?

    init() {
        super.init(frame: .zero)
        dressCivil(.hourMinute)
        target = self
        action = #selector(changed(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTimePickerView is created in code")
    }

    /// The time the picker shows.
    var time: ClockTime { time(of: dateValue) }

    /// The time shown, added up from midnight around the day; none leaves the time shown.
    func setTime(_ time: ClockTime?) {
        guard let time, let instant = instant(of: CalendarArithmetic.clock(time)) else { return }
        ProgramWrite.perform { dateValue = instant }
    }

    @objc private func changed(_ sender: NSDatePicker) {
        guard !ProgramWrite.isWriting else { return }
        onChosen?(time)
    }

    /// Picks `time` as the user does.
    func chooseForTesting(_ time: ClockTime) {
        guard let instant = instant(of: CalendarArithmetic.clock(time)) else { return }
        dateValue = instant
        changed(self)
    }
}

#endif
