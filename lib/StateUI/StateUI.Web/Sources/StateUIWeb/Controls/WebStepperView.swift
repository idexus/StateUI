// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Stepper: a field of words with the role of a spin button between a button taking a step down and one taking a
/// step up, the keyboard's arrows a step too - each a whole step from where it stands, kept inside its range. Words
/// that say no number, wholly, leave the number where it was; a step or words that move nothing are heard by nobody.
/// Design: docs/design/platforms/web/controls.md#values-in-a-range
@MainActor
final class WebStepperView: WebDOMView {
    private let down = WebDOMView(tag: "button")
    private let field = WebDOMView(tag: "input")
    private let up = WebDOMView(tag: "button")

    /// The user moved the value, to the one it stands at.
    var onValueChanged: (Double) -> Void = { _ in }

    /// The value as last written or moved, and the range and step it moves in.
    private(set) var value = 0.0
    private var range = (lower: 0.0, upper: 100.0)
    private(set) var step = 1.0
    private var decimals = 0

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-stepper")
        attribute("role", "group")
        field.attribute("type", "text")
        field.attribute("role", "spinbutton")
        field.attribute("inputmode", "decimal")
        for (button, words, sign) in [(down, "Decrease", "−"), (up, "Increase", "+")] {
            button.attribute("type", "button")
            button.attribute("aria-label", words)
            WebRelay.setText(button.node, sign)
        }
        for (index, part) in [down, field, up].enumerated() { WebRelay.insert(part.node, into: node, at: index) }
        down.listen("click") { [weak self] in self?.stepped(by: -1) }
        up.listen("click") { [weak self] in self?.stepped(by: 1) }
        field.listen("steps") { [weak self] in self?.stepped(by: WebRelay.eventDetail < 0 ? -1 : 1) }
        field.listen("change") { [weak self] in self?.typed() }
    }

    override var role: String? { "group" }

    override var isControl: Bool { true }

    /// The range and the step, then `value`, kept inside the range; written with as many decimals as they take.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double) {
        range = ValueArithmetic.range(minimum, maximum)
        self.step = ValueArithmetic.step(step)
        decimals = ValueArithmetic.decimals(of: [self.step, range.lower, range.upper, value])
        field.attribute("aria-valuemin", WebCSS.number(range.lower))
        field.attribute("aria-valuemax", WebCSS.number(range.upper))
        show(within(value))
    }

    private func show(_ value: Double) {
        self.value = value
        let words = WebCSS.number(value, decimals: decimals)
        WebRelay.setValue(field.node, words)
        field.attribute("aria-valuenow", words)
    }

    private func within(_ number: Double) -> Double {
        min(max(number, range.lower), range.upper)
    }

    private func stepped(by steps: Double) {
        moved(to: within(value + steps * step))
    }

    /// The user typed: words wholly a number stand inside the range, anything else gives way to the number before.
    private func typed() {
        let words = WebRelay.value(of: field.node).drop(while: \.isWhitespace)
        let number = words.dropLast(words.reversed().prefix(while: \.isWhitespace).count)
        guard let typed = Double(number), typed.isFinite else { return show(value) }
        moved(to: within(typed))
    }

    private func moved(to number: Double) {
        let changed = number != value
        show(number)
        if changed { onValueChanged(number) }
    }

    override func setEnabled(_ enabled: Bool) {
        for part in [down, field, up] { part.attribute("disabled", enabled ? nil : "") }
    }

    override func detach() {
        for part in [down, field, up] { part.detach() }
        super.detach()
    }
}
