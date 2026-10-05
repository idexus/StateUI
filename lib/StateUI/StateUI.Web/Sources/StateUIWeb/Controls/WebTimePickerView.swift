// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TimePicker: the browser's time `<input>`, its time written in the user's own clock - with its seconds where it
/// has some; the time shown again when the user leaves the field empty.
/// Design: docs/design/platforms/web/controls.md#a-day-and-a-time
@MainActor
final class WebTimePickerView: WebDOMView, WebWordsView {
    /// The user chose a time.
    var onChosen: (ClockTime) -> Void = { _ in }

    /// The time the picker holds, as last written or chosen.
    private var shown: ClockTime?

    init() {
        super.init(tag: "input")
        attribute("type", "time")
        attribute("required", "")
        listen("change") { [weak self] in self?.picked() }
        listen("blur") { [weak self] in self?.left() }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The time shown, within the day; none leaves the time shown.
    func setTime(_ time: ClockTime?) {
        guard let time else { return }
        let clock = CalendarArithmetic.clock(time)
        guard clock != shown else { return }
        shown = clock
        steps(clock)
        WebRelay.setValue(node, Self.written(clock))
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The time the field holds now, told.
    private func picked() {
        guard let typed = ClockTime(WebRelay.value(of: node)).map(CalendarArithmetic.clock), typed != shown else {
            return
        }
        shown = typed
        steps(typed)
        onChosen(typed)
    }

    /// The field steps by seconds while its time has some, else by minutes.
    private func steps(_ time: ClockTime) {
        attribute("step", time.second == 0 ? nil : "1")
    }

    /// The user left the field: it shows the time the picker holds.
    private func left() {
        WebRelay.setValue(node, shown.map(Self.written) ?? "")
    }

    /// The time as the field's value: hours and minutes, and the seconds where there are some.
    private static func written(_ time: ClockTime) -> String {
        time.second == 0 ? String(time.text.prefix(5)) : time.text
    }
}
