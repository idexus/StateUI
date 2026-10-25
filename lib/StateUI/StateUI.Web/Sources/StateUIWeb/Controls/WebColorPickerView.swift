// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ColorPicker: the browser's color `<input>`, which opens its platform's own picker; each color the user chooses
/// there is reported as the host layer reports it - opaque, as the input chooses no opacity.
/// Design: docs/design/platforms/web/controls.md#a-color-picker
@MainActor
final class WebColorPickerView: WebDOMView {
    /// The user chose a color.
    var onChosen: (Color) -> Void = { _ in }

    init() {
        super.init(tag: "input")
        attribute("type", "color")
        listen("input") { [weak self] in self?.picked() }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The color the input shows, its six hex digits; the input holds no opacity.
    func setColor(_ color: Color) {
        guard let (red, green, blue, _) = color.propValue.color else { return }
        let digits = [red, green, blue].map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }
        WebRelay.setValue(node, "#" + digits.joined())
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The color the input holds now, told.
    private func picked() {
        guard let held = Color(parsing: WebRelay.value(of: node))?.propValue.fractions else { return }
        onChosen(ColorChoice.reported(held, choosesOpacity: false))
    }
}
