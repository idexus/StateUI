// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Switch: the browser's checkbox with the role of a switch, drawn as one; a CheckBox: the checkbox as it is. Each
/// stands in a `<label>` that takes the view's frame, so a click anywhere in the frame turns it, and says when the
/// user turns it: alone, at its own size in the middle; with words, a switch at the end after them, a box at the
/// start before them.
/// Design: docs/design/platforms/web/controls.md#toggles
@MainActor
final class WebSwitchView: WebDOMView {
    private let box = WebDOMView(tag: "input")

    /// The words it says beside it, which name it.
    let caption = WebDOMView(tag: "span")

    /// The user turned it, to on or off.
    var onToggled: (Bool) -> Void = { _ in }

    init(switch isSwitch: Bool) {
        super.init(tag: "label")
        attribute("class", "stateui-toggle")
        box.attribute("type", "checkbox")
        if isSwitch {
            box.attribute("role", "switch")
            box.attribute("class", "stateui-switch")
        }
        WebRelay.insert(box.node, into: node, at: 0)
        WebRelay.insert(caption.node, into: node, at: isSwitch ? 0 : 1)
        box.listen("change") { [weak self] in
            guard let self else { return }
            onToggled(WebRelay.flag(of: box.node, "checked"))
        }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    override var named: WebDOMView { box }

    func setOn(_ on: Bool) {
        WebRelay.setFlag(box.node, "checked", on)
    }

    /// The words it says beside it, and their colour; empty words show none.
    func setWords(_ words: String, color: HostValue?) {
        WebRelay.setText(caption.node, words)
        caption.style("color", WebCSS.color(color))
        attribute("data-words", words.isEmpty ? nil : "")
    }

    override func setEnabled(_ enabled: Bool) {
        box.attribute("disabled", enabled ? nil : "")
        attribute("aria-disabled", enabled ? nil : "true")
    }

    /// The colour it shows when on; nil for the page's accent.
    func setTint(_ tint: HostValue?) {
        style("accent-color", WebCSS.color(tint))
        style("--stateui-on", WebCSS.color(tint))
    }

    override func release() {
        box.release()
        caption.release()
        super.release()
    }
}
