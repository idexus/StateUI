// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A DatePicker or a TimePicker: UIKit's own, compact - a day of the calendar or a time of the clock, which belong
/// to no zone, so it counts in the Gregorian calendar at UTC and shows them there. The user's pick is reported; the
/// program's is only shown.
@MainActor
final class UIKitDateTimePickerView: UIDatePicker {
    /// What the picker does when the user picked, handed the day's lanes - year, month, day - or the time's - hour,
    /// minute, second.
    var onValueChanged: (([Double]) -> Void)?

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    init(mode: UIDatePicker.Mode) {
        super.init(frame: .zero)
        datePickerMode = mode
        preferredDatePickerStyle = .compact
        calendar = Self.calendar
        timeZone = Self.calendar.timeZone
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onValueChanged?(lanes)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitDateTimePickerView is made in code")
    }

    /// The picked day's or time's lanes.
    var lanes: [Double] {
        let parts = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return datePickerMode == .time
            ? [Double(parts.hour ?? 0), Double(parts.minute ?? 0), 0]
            : [Double(parts.year ?? 0), Double(parts.month ?? 1), Double(parts.day ?? 1)]
    }

    /// The value where the tree wrote one, and the earliest and latest day it lets the user pick.
    func apply(value: [Double]?, minimum: [Double]?, maximum: [Double]?) {
        minimumDate = minimum.flatMap(Self.date)
        maximumDate = maximum.flatMap(Self.date)
        if let value, let date = datePickerMode == .time ? Self.time(value) : Self.date(value) { self.date = date }
    }

    private static func date(_ lanes: [Double]) -> Date? {
        guard lanes.count >= 3 else { return nil }
        return calendar.date(from: DateComponents(year: Int(lanes[0]), month: Int(lanes[1]), day: Int(lanes[2])))
    }

    private static func time(_ lanes: [Double]) -> Date? {
        guard lanes.count >= 2 else { return nil }
        return calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: Int(lanes[0]), minute: Int(lanes[1])))
    }
}
#endif
