// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Slider: the browser's range, saying each move of its thumb as it goes.
/// Design: docs/design/platforms/web/controls.md#values-in-a-range
@MainActor
final class WebSliderView: WebDOMView {
    /// The user moved the thumb, to the value it stands at.
    var onValueChanged: (Double) -> Void = { _ in }

    init() {
        super.init(tag: "input")
        attribute("type", "range")
        attribute("step", "any")
        listen("input") { [weak self] in
            guard let self else { return }
            onValueChanged(value)
        }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The value the thumb stands at.
    var value: Double {
        WebRelay.number(of: node, "valueAsNumber")
    }

    /// The range, then the value inside it.
    func apply(value: Double, minimum: Double, maximum: Double) {
        let (low, high) = ValueArithmetic.range(minimum, maximum)
        attribute("min", WebCSS.number(low))
        attribute("max", WebCSS.number(high))
        WebRelay.setNumber(node, "valueAsNumber", value)
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The colour of the run behind the thumb; nil for the page's accent.
    func setTint(_ tint: HostValue?) {
        style("accent-color", WebCSS.color(tint))
        style("--stateui-on", WebCSS.color(tint))
    }
}
