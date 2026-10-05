// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A RadioButton: a `<label>` holding the browser's radio button and its caption, a click anywhere on it a choice.
/// Its group is the host layer's: the button holds no `name`, so the browser turns no peer off of itself.
/// Design: docs/design/platforms/web/controls.md#toggles
@MainActor
final class WebRadioView: WebDOMView, WebWordsView {
    private let button = WebDOMView(tag: "input")
    private let caption = WebDOMView(tag: "span")

    /// The user turned it on.
    var onToggled: (Bool) -> Void = { _ in }

    init() {
        super.init(tag: "label")
        attribute("class", "stateui-radio")
        button.attribute("type", "radio")
        WebRelay.insert(button.node, into: node, at: 0)
        WebRelay.insert(caption.node, into: node, at: 1)
        button.listen("change") { [weak self] in
            guard let self else { return }
            onToggled(WebRelay.flag(of: button.node, "checked"))
        }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    func setText(_ text: String) {
        WebRelay.setText(caption.node, text)
    }

    func setOn(_ on: Bool) {
        WebRelay.setFlag(button.node, "checked", on)
    }

    override func setEnabled(_ enabled: Bool) {
        button.attribute("disabled", enabled ? nil : "")
        attribute("aria-disabled", enabled ? nil : "true")
    }

    override func detach() {
        button.detach()
        caption.detach()
        super.detach()
    }
}
