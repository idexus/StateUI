// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Stepper: a number field between a button taking a step down and one taking a step up, the field's own steps
/// kept inside its range. Words that say no number leave the number where it was.
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
    private var decimals = 0

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-stepper")
        attribute("role", "group")
        field.attribute("type", "number")
        field.attribute("inputmode", "decimal")
        for (button, words, sign) in [(down, "Decrease", "−"), (up, "Increase", "+")] {
            button.attribute("type", "button")
            button.attribute("aria-label", words)
            WebRelay.setText(button.node, sign)
        }
        for (index, part) in [down, field, up].enumerated() { WebRelay.insert(part.node, into: node, at: index) }
        down.listen("click") { [weak self] in self?.stepped(by: -1) }
        up.listen("click") { [weak self] in self?.stepped(by: 1) }
        field.listen("change") { [weak self] in self?.typed() }
    }

    override var role: String? { "group" }

    override var isControl: Bool { true }

    /// The range and the step, then `value`, kept inside the range; written with as many decimals as they take.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double) {
        range = ValueArithmetic.range(minimum, maximum)
        let step = ValueArithmetic.step(step)
        decimals = ValueArithmetic.decimals(of: [step, range.lower, range.upper, value])
        field.attribute("min", WebCSS.number(range.lower))
        field.attribute("max", WebCSS.number(range.upper))
        field.attribute("step", WebCSS.number(step))
        show(min(max(value, range.lower), range.upper))
    }

    private func show(_ value: Double) {
        self.value = value
        WebRelay.setValue(field.node, WebCSS.number(value, decimals: decimals))
    }

    private func stepped(by steps: Int32) {
        WebRelay.step(field.node, by: steps)
        moved(to: WebRelay.number(of: field.node, "valueAsNumber"))
    }

    /// The user typed: a number stands inside the range, anything else gives way to the number before it.
    private func typed() {
        let typed = WebRelay.number(of: field.node, "valueAsNumber")
        guard typed.isFinite else { return show(value) }
        moved(to: min(max(typed, range.lower), range.upper))
    }

    private func moved(to number: Double) {
        guard number.isFinite else { return show(value) }
        show(number)
        onValueChanged(number)
    }

    override func setEnabled(_ enabled: Bool) {
        for part in [down, field, up] { part.attribute("disabled", enabled ? nil : "") }
    }

    override func detach() {
        for part in [down, field, up] { part.detach() }
        super.detach()
    }
}
