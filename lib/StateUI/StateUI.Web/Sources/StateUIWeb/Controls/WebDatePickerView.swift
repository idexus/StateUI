// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A DatePicker: the browser's date `<input>`, its day written in the user's own way and its calendar offering the
/// days of the range; a day typed past the range stands at its end (`CalendarArithmetic`) once the user leaves the
/// field, as does the day shown when the field is left empty.
/// Design: docs/design/platforms/web/controls.md#a-day-and-a-time
@MainActor
final class WebDatePickerView: WebDOMView, WebWordsView {
    /// The user chose a day.
    var onChosen: (CalendarDate) -> Void = { _ in }

    /// The day the picker holds, as last written or chosen.
    private var shown: CalendarDate?

    /// The earliest and the latest day the picker holds, in order; nil for none.
    private var range: (earliest: CalendarDate?, latest: CalendarDate?) = (nil, nil)

    init() {
        super.init(tag: "input")
        attribute("type", "date")
        attribute("required", "")
        listen("change") { [weak self] in self?.picked() }
        listen("blur") { [weak self] in self?.left() }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The day shown, held within the range; one not in the calendar, or none, leaves the day shown.
    func setDate(_ date: CalendarDate?) {
        guard let date, let held = CalendarArithmetic.held(date, earliest: range.earliest, latest: range.latest),
              held != shown
        else { return }
        shown = held
        WebRelay.setValue(node, held.text)
    }

    /// The earliest and the latest day the picker holds; the day shown moves within them.
    func setRange(earliest: CalendarDate?, latest: CalendarDate?) {
        range = CalendarArithmetic.range(earliest, latest)
        attribute("min", range.earliest?.text)
        attribute("max", range.latest?.text)
        setDate(shown)
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The day the field holds now, held within the range, then told; the field itself is written again only as
    /// the user leaves it, so a year typed digit by digit is not taken from under the user's keys.
    private func picked() {
        guard let typed = CalendarDate(WebRelay.value(of: node)) else { return }
        let held = CalendarArithmetic.held(typed, earliest: range.earliest, latest: range.latest) ?? shown ?? typed
        guard held != shown else { return }
        shown = held
        onChosen(held)
    }

    /// The user left the field: it shows the day the picker holds.
    private func left() {
        WebRelay.setValue(node, shown?.text ?? "")
    }
}
