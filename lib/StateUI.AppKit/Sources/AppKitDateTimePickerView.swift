// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

enum AppKitDateTimePickerMode {
    case date
    case time
}

/// AppKit's native civil-date and clock-minute control.
///
/// The fixed Gregorian conversion is deliberately local to the host. StateUI
/// keeps a civil date and a time of day as numeric lanes, never as an absolute
/// instant whose zone conversion could change the reader's chosen value.
@MainActor
final class AppKitDateTimePickerView: NSDatePicker {
    var onValueChanged: (([Double]) -> Void)?

    private let mode: AppKitDateTimePickerMode
    private var civilCalendar: Calendar
    private var applying = false

    init(mode: AppKitDateTimePickerMode) {
        self.mode = mode
        civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.locale = .current
        civilCalendar.timeZone = .current
        super.init(frame: .zero)

        calendar = civilCalendar
        locale = .current
        timeZone = .current
        datePickerStyle = .textFieldAndStepper
        datePickerElements = mode == .date ? .yearMonthDay : .hourMinute
        target = self
        action = #selector(changed(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitDateTimePickerView is created in code")
    }

    func apply(
        value: [Double]?,
        writeValue: Bool,
        minimum: [Double]?,
        maximum: [Double]?,
        font: NSFont,
        textColor: NSColor,
        enabled: Bool
    ) {
        applying = true
        self.font = font
        self.textColor = textColor
        isEnabled = enabled

        if mode == .date {
            applyDateRange(minimum: minimum, maximum: maximum)
        } else {
            minDate = nil
            maxDate = nil
        }

        if writeValue, let value, let native = nativeDate(from: value) {
            dateValue = clamped(native)
        }
        applying = false
    }

    private func applyDateRange(minimum: [Double]?, maximum: [Double]?) {
        var lower = minimum.flatMap(exactCivilDate)
        var upper = maximum.flatMap(exactCivilDate)
        if let first = lower, let last = upper, first > last {
            swap(&lower, &upper)
        }
        minDate = lower
        maxDate = upper
    }

    private func clamped(_ date: Date) -> Date {
        if let minDate, date < minDate { return minDate }
        if let maxDate, date > maxDate { return maxDate }
        return date
    }

    private func nativeDate(from lanes: [Double]) -> Date? {
        switch mode {
        case .date:
            return exactCivilDate(lanes)
        case .time:
            return normalizedClockDate(lanes)
        }
    }

    private func exactCivilDate(_ lanes: [Double]) -> Date? {
        guard lanes.count == 3,
              let year = whole(lanes[0]),
              let month = whole(lanes[1]),
              let day = whole(lanes[2])
        else { return nil }

        let components = DateComponents(
            calendar: civilCalendar,
            timeZone: civilCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12)
        guard let date = civilCalendar.date(from: components) else { return nil }
        let read = civilCalendar.dateComponents([.year, .month, .day], from: date)
        guard read.year == year, read.month == month, read.day == day else { return nil }
        return date
    }

    private func normalizedClockDate(_ lanes: [Double]) -> Date? {
        guard lanes.count == 3,
              let hour = whole(lanes[0]),
              let minute = whole(lanes[1]),
              let second = whole(lanes[2])
        else { return nil }

        let secondsPerDay = 24 * 60 * 60
        let hours = hour.multipliedReportingOverflow(by: 60 * 60)
        let minutes = minute.multipliedReportingOverflow(by: 60)
        guard !hours.overflow, !minutes.overflow else { return nil }
        let plusMinutes = hours.partialValue.addingReportingOverflow(minutes.partialValue)
        guard !plusMinutes.overflow else { return nil }
        let plusSeconds = plusMinutes.partialValue.addingReportingOverflow(second)
        guard !plusSeconds.overflow else { return nil }
        let normalized = (plusSeconds.partialValue % secondsPerDay + secondsPerDay)
            % secondsPerDay

        let components = DateComponents(
            calendar: civilCalendar,
            timeZone: civilCalendar.timeZone,
            year: 2001,
            month: 1,
            day: 1,
            hour: normalized / 3_600,
            minute: normalized % 3_600 / 60,
            second: 0)
        return civilCalendar.date(from: components)
    }

    private func whole(_ value: Double) -> Int? {
        guard value.isFinite else { return nil }
        return Int(exactly: value.rounded())
    }

    private func lanes(from date: Date) -> [Double] {
        switch mode {
        case .date:
            let parts = civilCalendar.dateComponents([.year, .month, .day], from: date)
            return [parts.year, parts.month, parts.day].map { Double($0 ?? 0) }
        case .time:
            let parts = civilCalendar.dateComponents([.hour, .minute], from: date)
            return [Double(parts.hour ?? 0), Double(parts.minute ?? 0), 0]
        }
    }

    @objc private func changed(_ sender: NSDatePicker) {
        guard !applying else { return }
        onValueChanged?(lanes(from: dateValue))
    }

    var valueLanesForTesting: [Double] { lanes(from: dateValue) }
    var minimumLanesForTesting: [Double]? { minDate.map(lanes) }
    var maximumLanesForTesting: [Double]? { maxDate.map(lanes) }

    func changeForTesting(to lanes: [Double]) {
        guard let date = nativeDate(from: lanes) else { return }
        dateValue = clamped(date)
        changed(self)
    }
}

#endif
