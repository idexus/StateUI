// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TimePicker: UIKit's own, compact, a time added up from midnight around the day by the host layer's rule
/// (`CalendarArithmetic`). The user's pick is reported; the program's is only shown.
@MainActor
final class UIKitTimePickerView: UIDatePicker {
    /// What the picker does as the user picks a time.
    var onChosen: ((ClockTime) -> Void)?

    init() {
        super.init(frame: .zero)
        dressCivil(.time)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onChosen?(time)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitTimePickerView is made in code")
    }

    /// The time the picker shows.
    var time: ClockTime { Self.time(of: date) }

    /// The time shown, added up from midnight around the day; none leaves the time shown.
    func setTime(_ time: ClockTime?) {
        guard let time, let instant = Self.instant(of: CalendarArithmetic.clock(time)) else { return }
        date = instant
    }
}
#endif
