// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A DatePicker: WinUI's `CalendarDatePicker`, its day written in the user's own way, and its calendar, which the
/// user opens, closes and picks from.
/// Design: docs/design/platforms/winui/controls.md#a-day-and-a-time
@MainActor
final class WinUIDatePickerView: WinUIView {
    /// What the picker does as the user picks a day, opens the calendar and closes it.
    var onChosen: ((CalendarDate) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    private var showing = WinUIShowing()

    init() {
        super.init { number in stateui_winui_date_make(number) }
    }

    /// The day shown; nil for none.
    func setDate(_ date: CalendarDate?) {
        stateui_winui_date_set(
            handle, date != nil, Int32(clamping: date?.year ?? 0), Int32(clamping: date?.month ?? 0),
            Int32(clamping: date?.day ?? 0))
    }

    /// The earliest and the latest day the calendar offers; nil for WinUI's own.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        func parts(_ date: CalendarDate?) -> [Int32]? {
            date.map { [Int32(clamping: $0.year), Int32(clamping: $0.month), Int32(clamping: $0.day)] }
        }
        let first = parts(earliest), last = parts(latest)
        first.withOptionalBuffer { first in
            last.withOptionalBuffer { last in stateui_winui_date_set_range(handle, first, last) }
        }
    }

    /// How the day is written: "D" the long form, anything else the short.
    func setFormat(_ format: String?) {
        stateui_winui_date_set_format(handle, format == "D")
    }

    /// Opens or closes the calendar; neither is the user's, so neither is reported.
    func setOpen(_ open: Bool) {
        if showing.programAsks(open: open, shown: isOpen) { stateui_winui_date_set_open(handle, open) }
    }

    /// Whether the calendar shows.
    var isOpen: Bool { stateui_winui_date_is_open(handle) }

    /// The day WinUI shows; nil for none.
    var date: CalendarDate? {
        var parts: [Int32] = [0, 0, 0]
        guard stateui_winui_date(handle, &parts) else { return nil }
        return CalendarDate(year: Int(parts[0]), month: Int(parts[1]), day: Int(parts[2]))
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func picked(_ first: Int32, _ second: Int32, _ third: Int32) {
        onChosen?(CalendarDate(year: Int(first), month: Int(second), day: Int(third)))
    }

    override func presented(_ open: Bool) {
        guard showing.heard(open: open) else { return }
        if open { onOpened?() } else { onClosed?() }
    }

    override func detach() {
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}

private extension Optional where Wrapped == [Int32] {
    /// The numbers' first address for the call, or null where there are none.
    func withOptionalBuffer<Result>(_ body: (UnsafePointer<Int32>?) -> Result) -> Result {
        guard let numbers = self else { return body(nil) }
        return numbers.withUnsafeBufferPointer { body($0.baseAddress) }
    }
}
