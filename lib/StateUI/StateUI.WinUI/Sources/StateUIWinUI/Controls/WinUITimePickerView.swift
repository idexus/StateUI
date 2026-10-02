// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A TimePicker: WinUI's `TimePicker`, in the user's clock.
/// Design: docs/design/platforms/winui/controls.md#a-day-and-a-time
@MainActor
final class WinUITimePickerView: WinUIView {
    override var takesDirection: Bool { true }

    /// What the picker does as the user picks a time.
    var onChosen: ((ClockTime) -> Void)?

    init() {
        super.init { number in stateui_winui_time_make(number) }
    }

    /// The time shown, added up from midnight around the day (`CalendarArithmetic`); nil for none.
    func setTime(_ time: ClockTime?) {
        let clock = time.map(CalendarArithmetic.clock)
        stateui_winui_time_set(
            handle, clock != nil, Int32(clamping: clock?.hour ?? 0), Int32(clamping: clock?.minute ?? 0))
    }

    /// The time WinUI shows; nil for none.
    var time: ClockTime? {
        var parts: [Int32] = [0, 0]
        guard stateui_winui_time(handle, &parts) else { return nil }
        return ClockTime(hour: Int(parts[0]), minute: Int(parts[1]))
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func picked(_ first: Int32, _ second: Int32, _ third: Int32) {
        onChosen?(ClockTime(hour: Int(first), minute: Int(second)))
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
